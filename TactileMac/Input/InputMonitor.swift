import CoreGraphics
import Foundation
import QuartzCore

/// A listen-only event tap. It never modifies, suppresses, logs, or inspects
/// text input; the callback only reads hardware key codes and pointer deltas.
final class InputMonitor {
    var onEvent: ((NormalizedInputEvent) -> Void)?
    var onError: ((String) -> Void)?
    var onRunningChanged: ((Bool) -> Void)?

    private var tapPort: CFMachPort?
    private var tapRunLoop: CFRunLoop?
    private var tapThread: Thread?
    private var pressedKeys = Set<Int64>()
    private var pressedModifiers = Set<Int64>()
    private let stateLock = NSLock()

    var isRunning: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return tapPort != nil
    }

    @discardableResult
    func start() -> Bool {
        stateLock.lock()
        let already = tapPort != nil
        stateLock.unlock()
        if already { return true }

        let eventTypes: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
            .scrollWheel
        ]
        var mask: CGEventMask = 0
        for eventType in eventTypes {
            mask |= CGEventMask(1) << CGEventMask(eventType.rawValue)
        }

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: inputTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            onError?("The input event tap could not be created. Grant Input Monitoring in System Settings, then try again. Some macOS versions also require relaunching TactileMac after granting access.")
            return false
        }

        stateLock.lock()
        tapPort = port
        stateLock.unlock()

        let thread = Thread { [weak self] in
            guard let self, let port = self.tapPort else { return }
            let runLoop = CFRunLoopGetCurrent()
            self.tapRunLoop = runLoop
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
            self.onRunningChanged?(true)
            CFRunLoopRun()
        }
        thread.name = "com.tactilemac.inputTap"
        thread.qualityOfService = .userInteractive
        tapThread = thread
        thread.start()
        return true
    }

    func stop() {
        stateLock.lock()
        let port = tapPort
        let runLoop = tapRunLoop
        tapPort = nil
        tapRunLoop = nil
        pressedKeys.removeAll()
        pressedModifiers.removeAll()
        stateLock.unlock()

        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let runLoop { CFRunLoopStop(runLoop) }
        tapThread = nil
        onRunningChanged?(false)
    }

    fileprivate func process(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            stateLock.lock()
            let port = tapPort
            stateLock.unlock()
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            onError?("macOS disabled the input tap briefly; it was re-enabled automatically.")
            return
        case .keyDown, .keyUp:
            processKey(type: type, event: event)
        case .flagsChanged:
            processFlags(event: event)
        case .leftMouseDown, .leftMouseUp:
            onEvent?(.mouseButton(button: .left, isDown: type == .leftMouseDown, timestamp: CACurrentMediaTime()))
        case .rightMouseDown, .rightMouseUp:
            onEvent?(.mouseButton(button: .right, isDown: type == .rightMouseDown, timestamp: CACurrentMediaTime()))
        case .otherMouseDown, .otherMouseUp:
            let number = event.getIntegerValueField(.mouseEventButtonNumber)
            let button: MouseButtonName = number == 2 ? .middle : .other
            onEvent?(.mouseButton(button: button, isDown: type == .otherMouseDown, timestamp: CACurrentMediaTime()))
        case .scrollWheel:
            processScroll(event: event)
        default:
            break
        }
    }

    private func processKey(type: CGEventType, event: CGEvent) {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if type == .keyDown {
            stateLock.lock()
            let isDuplicate = pressedKeys.contains(code) && !isRepeat
            if !isRepeat { pressedKeys.insert(code) }
            stateLock.unlock()
            if isDuplicate { return }
            onEvent?(.keyDown(code: code, isRepeat: isRepeat, timestamp: CACurrentMediaTime()))
        } else {
            stateLock.lock()
            let existed = pressedKeys.remove(code) != nil
            stateLock.unlock()
            if !existed { return }
            onEvent?(.keyUp(code: code, timestamp: CACurrentMediaTime()))
        }
    }

    private func processFlags(event: CGEvent) {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if code == 57 {
            // Caps Lock reports lock state, not key state. Every flags change is
            // a physical press; send one down event rather than inventing an up.
            onEvent?(.modifierChanged(code: code, isDown: true, timestamp: CACurrentMediaTime()))
            return
        }
        guard let flag = Self.modifierFlags[code] else { return }
        let isDown = event.flags.contains(flag)
        stateLock.lock()
        let changed: Bool
        if isDown {
            changed = pressedModifiers.insert(code).inserted
        } else {
            changed = pressedModifiers.remove(code) != nil
        }
        stateLock.unlock()
        guard changed else { return }
        onEvent?(.modifierChanged(code: code, isDown: isDown, timestamp: CACurrentMediaTime()))
    }

    private func processScroll(event: CGEvent) {
        var delta = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        if delta == 0 {
            delta = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        }
        let isPrecise = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
        onEvent?(.scroll(deltaY: delta, isPrecise: isPrecise, isMomentum: momentum, timestamp: CACurrentMediaTime()))
    }

    private static let modifierFlags: [Int64: CGEventFlags] = [
        54: .maskCommand, 55: .maskCommand,
        56: .maskShift, 60: .maskShift,
        58: .maskAlternate, 61: .maskAlternate,
        59: .maskControl, 62: .maskControl,
        63: .maskSecondaryFn
    ]
}

private let inputTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    if let userInfo {
        let monitor = Unmanaged<InputMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.process(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}
