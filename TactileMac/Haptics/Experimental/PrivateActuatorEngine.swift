import Darwin
import Foundation

/// Experimental, isolated access to the Force Touch actuator through
/// MultitouchSupport.framework. This is a private framework: it is not a
/// public compatibility promise, can change with macOS, and must not be the
/// only haptic path. `HapticEngine` falls back to AppKit if `isAvailable` is
/// false. It is loaded only when the enhanced path is requested.
///
/// The symbols and the 3/4/6 actuation IDs follow publicly documented research
/// notes. This is an independent adapter; no third-party implementation code is
/// used.
final class PrivateActuatorEngine {
    static let shared = PrivateActuatorEngine()

    private typealias CreateFunc = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
    private typealias OpenFunc = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias CloseFunc = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias ActuateFunc = @convention(c) (UnsafeMutableRawPointer, Int32, UInt32, Float, Float) -> Int32
    private typealias ListFunc = @convention(c) () -> Unmanaged<CFArray>?
    private typealias GetIDFunc = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32

    private struct Actuator {
        let deviceID: UInt64
        let handle: UnsafeMutableRawPointer
    }

    private let lock = NSLock()
    private var actuators: [Actuator] = []
    private var closeHandle: CloseFunc?
    private var actuateHandle: ActuateFunc?
    private let frameworkHandle: UnsafeMutableRawPointer?

    private init() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let framework = dlopen(path, RTLD_NOW),
              let createSym = dlsym(framework, "MTActuatorCreateFromDeviceID"),
              let openSym = dlsym(framework, "MTActuatorOpen"),
              let closeSym = dlsym(framework, "MTActuatorClose"),
              let actuateSym = dlsym(framework, "MTActuatorActuate") else {
            frameworkHandle = nil
            return
        }
        frameworkHandle = framework

        let create = unsafeBitCast(createSym, to: CreateFunc.self)
        let open = unsafeBitCast(openSym, to: OpenFunc.self)
        closeHandle = unsafeBitCast(closeSym, to: CloseFunc.self)
        actuateHandle = unsafeBitCast(actuateSym, to: ActuateFunc.self)

        var opened: [Actuator] = []
        var seen = Set<UInt64>()

        if let listSym = dlsym(framework, "MTDeviceCreateList"),
           let idSym = dlsym(framework, "MTDeviceGetDeviceID") {
            let list = unsafeBitCast(listSym, to: ListFunc.self)
            let getID = unsafeBitCast(idSym, to: GetIDFunc.self)
            if let devices = list()?.takeRetainedValue() as? [AnyObject] {
                for device in devices {
                    let pointer = Unmanaged.passUnretained(device).toOpaque()
                    var deviceID: UInt64 = 0
                    guard getID(pointer, &deviceID) == 0, deviceID != 0, !seen.contains(deviceID) else {
                        continue
                    }
                    if let handle = create(deviceID), open(handle) == 0 {
                        opened.append(Actuator(deviceID: deviceID, handle: handle))
                        seen.insert(deviceID)
                    }
                }
            }
        }

        if opened.isEmpty {
            let legacyID: UInt64 = 0x200000001
            if let handle = create(legacyID), open(handle) == 0 {
                opened.append(Actuator(deviceID: legacyID, handle: handle))
            }
        }

        lock.lock()
        actuators = opened
        lock.unlock()

        if !opened.isEmpty {
            NSLog("TactileMac: private actuator available for %d device(s)", opened.count)
        } else {
            NSLog("TactileMac: private actuator unavailable; AppKit fallback is active")
        }
    }

    var isAvailable: Bool {
        lock.lock(); defer { lock.unlock() }
        return !actuators.isEmpty
    }

    var deviceCount: Int {
        lock.lock(); defer { lock.unlock() }
        return actuators.count
    }

    /// Fire one actuator pulse. The probe on the target hardware confirmed the
    /// handle is reusable, so material sequences do not recreate it per pulse.
    func pulse(_ actuationID: Int32) {
        lock.lock()
        let pulseHandles = actuators.map(\.handle)
        let actuate = actuateHandle
        lock.unlock()
        guard let actuate else { return }
        for handle in pulseHandles {
            _ = actuate(handle, actuationID, 0, 0, 0)
        }
    }

    deinit {
        lock.lock()
        let toClose = actuators
        let close = closeHandle
        actuators = []
        lock.unlock()
        if let close {
            for actuator in toClose {
                _ = close(actuator.handle)
                Unmanaged<AnyObject>.fromOpaque(actuator.handle).release()
            }
        }
        if let frameworkHandle { dlclose(frameworkHandle) }
    }
}
