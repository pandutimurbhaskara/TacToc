import AudioToolbox
import AVFoundation
import CoreAudio
import Foundation
import QuartzCore

enum AudioSource: String {
    case keyboard
    case trackpad
}

struct AudioOutputInfo: Equatable {
    var deviceName: String = "Unknown output"
    var sampleRate: Double = 0
    var hardwareBufferFrames: UInt32 = 0
    var deviceLatencyMs: Double = 0
    var safetyOffsetMs: Double = 0
    var computedOutputLatencyMs: Double = 0
    var isReady: Bool = false
}

protocol AudioPlaying: AnyObject {
    var isReady: Bool { get }
    func setVolumes(keyboard: Float, trackpad: Float)
    func setActivePacks(keyboard: String, trackpad: String)
    func install(_ pack: LoadedPack)
    func unloadPack(id: String)
    func setBufferFrames(_ frames: Int)
    func play(source: AudioSource, eventKeys: [String], pitchVariation: Double) -> Bool
    func preview(packID: String, eventKeys: [String], volume: Float) -> Bool
    func latencySnapshot() -> (last: Double?, average: Double?)
}

final class AudioEngine: AudioPlaying {
    private struct Voice {
        let audio: DecodedAudio
        let startFrame: Int
        let endFrame: Int
        var position: Double
        let rate: Double
        let gain: Float
        let source: AudioSource
        let enqueuedAt: TimeInterval
        var reportedPlayback: Bool
        let id: UInt64
    }

    private var queue: AudioQueueRef?
    private var buffers: [AudioQueueBufferRef] = []
    private var queueGeneration: UInt64 = 0
    private var ready = false
    private var outputSampleRate: Double = 48_000
    private var framesPerBuffer: UInt32 = 256
    private let channelCount: UInt32 = 2
    private let numberOfBuffers = 3
    private var format = AudioStreamBasicDescription()
    private var activeDeviceID: AudioDeviceID = 0
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var deviceListenerAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var rebuildWork: DispatchWorkItem?
    private var outputInfoValue = AudioOutputInfo()
    private var lastErrorMessage: String?

    private let stateLock = NSLock()
    private let voiceLock = NSLock()
    private var audioThread: Thread?
    private var audioRunLoop: CFRunLoop?
    private let runLoopReady = DispatchSemaphore(value: 0)
    private var voices: [Voice] = []
    private var keyboardVolume: Float = 0.65
    private var trackpadVolume: Float = 0.55
    private var keyboardPackID = "thock"
    private var trackpadPackID = "thock"
    private var library: [String: LoadedPack] = [:]
    private var libraryOrder: [String] = []
    private var nextVoiceID: UInt64 = 1
    private var recentLatencies: [Double] = []
    private let maximumVoices = 32
    private let maximumLibraryPacks = 8

    init(bufferFrames: Int = 256) {
        framesPerBuffer = UInt32(max(64, min(2048, bufferFrames)))
        startAudioRunLoop()
        installDeviceListener()
        createQueue()
    }

    /// AudioQueue callbacks are delivered on a dedicated run loop. Keeping
    /// them off the main run loop prevents SwiftUI layout work from starving
    /// the audio callback and producing CoreAudio overrun messages.
    private func startAudioRunLoop() {
        let thread = Thread { [weak self] in
            guard let self else { return }
            self.audioRunLoop = CFRunLoopGetCurrent()
            // A bare run loop exits when it has no sources. Keep it alive so
            // AudioQueue can attach its callback source after init returns.
            let keepAlive = Timer(timeInterval: 3600, repeats: true) { _ in }
            RunLoop.current.add(keepAlive, forMode: .common)
            self.runLoopReady.signal()
            CFRunLoopRun()
        }
        thread.name = "com.tactilemac.audioQueue"
        thread.qualityOfService = .userInteractive
        audioThread = thread
        thread.start()
        runLoopReady.wait()
    }

    deinit {
        rebuildWork?.cancel()
        if let block = deviceListener {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &deviceListenerAddress,
                DispatchQueue.main,
                block
            )
        }
        stateLock.lock()
        let queueToDispose = queue
        queue = nil
        ready = false
        stateLock.unlock()
        if let queueToDispose {
            AudioQueueStop(queueToDispose, true)
            AudioQueueDispose(queueToDispose, true)
        }
        if let runLoop = audioRunLoop {
            CFRunLoopStop(runLoop)
            CFRunLoopWakeUp(runLoop)
        }
        audioThread = nil
    }

    // MARK: - Public state

    var isReady: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return ready
    }

    var outputInfo: AudioOutputInfo {
        stateLock.lock(); defer { stateLock.unlock() }
        return outputInfoValue
    }

    var lastError: String? {
        stateLock.lock(); defer { stateLock.unlock() }
        return lastErrorMessage
    }

    func setVolumes(keyboard: Float, trackpad: Float) {
        voiceLock.lock()
        keyboardVolume = min(max(keyboard, 0), 1)
        trackpadVolume = min(max(trackpad, 0), 1)
        voiceLock.unlock()
    }

    func setActivePacks(keyboard: String, trackpad: String) {
        voiceLock.lock()
        keyboardPackID = keyboard
        trackpadPackID = trackpad
        voiceLock.unlock()
        trimLibrary()
    }

    func install(_ pack: LoadedPack) {
        voiceLock.lock()
        library[pack.manifest.id] = pack
        libraryOrder.removeAll { $0 == pack.manifest.id }
        libraryOrder.append(pack.manifest.id)
        trimLibraryLocked()
        voiceLock.unlock()
    }

    func unloadPack(id: String) {
        voiceLock.lock()
        library.removeValue(forKey: id)
        libraryOrder.removeAll { $0 == id }
        voiceLock.unlock()
    }

    func setBufferFrames(_ frames: Int) {
        let clamped = UInt32(max(64, min(2048, frames)))
        stateLock.lock()
        let changed = clamped != framesPerBuffer
        stateLock.unlock()
        guard changed else { return }
        stateLock.lock()
        framesPerBuffer = clamped
        stateLock.unlock()
        scheduleRebuild(delay: 0.05)
    }

    // MARK: - Playback

    @discardableResult
    func play(source: AudioSource, eventKeys: [String], pitchVariation: Double) -> Bool {
        stateLock.lock()
        let readyNow = ready
        stateLock.unlock()
        guard readyNow else {
            stateLock.lock(); lastErrorMessage = "Audio output is not ready."; stateLock.unlock()
            return false
        }
        voiceLock.lock()
        let packID = source == .keyboard ? keyboardPackID : trackpadPackID
        guard let pack = library[packID],
              let clip = selectClip(in: pack, eventKeys: eventKeys) else {
            voiceLock.unlock()
            return false
        }
        let variation = max(0, min(2, pitchVariation))
        let randomPitch = variation > 0 ? Double.random(in: -variation...variation) : 0
        let semitones = clip.pitchSemitones + randomPitch
        let rate = (clip.sample.sampleRate / outputSampleRateLocked()) * pow(2.0, semitones / 12.0)
        let voice = Voice(
            audio: clip.sample,
            startFrame: clip.startFrame,
            endFrame: clip.startFrame + clip.frameCount,
            position: Double(clip.startFrame),
            rate: rate,
            gain: clip.gain,
            source: source,
            enqueuedAt: CACurrentMediaTime(),
            reportedPlayback: false,
            id: nextVoiceID
        )
        nextVoiceID &+= 1
        if voices.count >= maximumVoices {
            voices.removeFirst(voices.count - maximumVoices + 1)
        }
        voices.append(voice)
        touchLibraryLocked(packID)
        voiceLock.unlock()
        return true
    }

    @discardableResult
    func preview(packID: String, eventKeys: [String], volume: Float) -> Bool {
        stateLock.lock()
        let readyNow = ready
        stateLock.unlock()
        guard readyNow else { return false }
        voiceLock.lock()
        guard let pack = library[packID], let clip = selectClip(in: pack, eventKeys: eventKeys) else {
            voiceLock.unlock()
            return false
        }
        let rate = (clip.sample.sampleRate / outputSampleRateLocked())
        let voice = Voice(
            audio: clip.sample,
            startFrame: clip.startFrame,
            endFrame: clip.startFrame + clip.frameCount,
            position: Double(clip.startFrame),
            rate: rate,
            gain: clip.gain * min(max(volume, 0), 1),
            source: .keyboard,
            enqueuedAt: CACurrentMediaTime(),
            reportedPlayback: false,
            id: nextVoiceID
        )
        nextVoiceID &+= 1
        if voices.count >= maximumVoices { voices.removeFirst(voices.count - maximumVoices + 1) }
        voices.append(voice)
        touchLibraryLocked(packID)
        voiceLock.unlock()
        return true
    }

    func latencySnapshot() -> (last: Double?, average: Double?) {
        voiceLock.lock(); defer { voiceLock.unlock() }
        let last = recentLatencies.last
        let average = recentLatencies.isEmpty ? nil : recentLatencies.reduce(0, +) / Double(recentLatencies.count)
        return (last, average)
    }

    private func selectClip(in pack: LoadedPack, eventKeys: [String]) -> ResolvedClip? {
        for key in eventKeys {
            if let clips = pack.clips[key], !clips.isEmpty {
                return clips.randomElement()
            }
        }
        return nil
    }

    private func outputSampleRateLocked() -> Double {
        stateLock.lock(); defer { stateLock.unlock() }
        return outputSampleRate
    }

    private func touchLibraryLocked(_ id: String) {
        libraryOrder.removeAll { $0 == id }
        libraryOrder.append(id)
        trimLibraryLocked()
    }

    private func trimLibrary() {
        voiceLock.lock(); trimLibraryLocked(); voiceLock.unlock()
    }

    private func trimLibraryLocked() {
        while libraryOrder.count > maximumLibraryPacks {
            guard let candidate = libraryOrder.first(where: { $0 != keyboardPackID && $0 != trackpadPackID }) else { break }
            libraryOrder.removeAll { $0 == candidate }
            library.removeValue(forKey: candidate)
        }
    }

    // MARK: - Queue

    private func installDeviceListener() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.scheduleRebuild(delay: 0.35) }
        }
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &deviceListenerAddress,
            DispatchQueue.main,
            block
        )
        if status == noErr {
            deviceListener = block
        } else {
            stateLock.lock()
            lastErrorMessage = "Could not observe the default output device (CoreAudio \(status))."
            stateLock.unlock()
        }
    }

    func handleWake() {
        scheduleRebuild(delay: 0.6)
    }

    private func scheduleRebuild(delay: TimeInterval) {
        rebuildWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.rebuild() }
        rebuildWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func rebuild() {
        stateLock.lock()
        queueGeneration &+= 1
        let oldQueue = queue
        queue = nil
        buffers = []
        ready = false
        outputInfoValue.isReady = false
        stateLock.unlock()

        if let oldQueue {
            AudioQueueStop(oldQueue, true)
            AudioQueueDispose(oldQueue, true)
        }
        voiceLock.lock()
        voices.removeAll()
        voiceLock.unlock()
        createQueue()
    }

    private func createQueue() {
        let deviceID = defaultOutputDeviceID()
        let sampleRate = deviceID.flatMap { nominalSampleRate($0) } ?? 48_000
        let info = queryOutputInfo(deviceID: deviceID, sampleRate: sampleRate)
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(MemoryLayout<Float>.size) * channelCount,
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(MemoryLayout<Float>.size) * channelCount,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        stateLock.lock()
        outputSampleRate = sampleRate
        outputInfoValue = info
        format = asbd
        let frames = framesPerBuffer
        let generation = queueGeneration
        stateLock.unlock()

        guard let deviceID else {
            stateLock.lock()
            lastErrorMessage = "No default audio output device is available."
            stateLock.unlock()
            return
        }

        var newQueue: AudioQueueRef?
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let status = AudioQueueNewOutput(
            &asbd,
            audioQueueCallback,
            selfPointer,
            audioRunLoop ?? CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue,
            0,
            &newQueue
        )
        guard status == noErr, let newQueue else {
            stateLock.lock()
            lastErrorMessage = "AudioQueue could not be created (status \(status))."
            stateLock.unlock()
            return
        }

        setQueueDevice(newQueue, deviceID: deviceID)

        let byteSize = UInt32(frames) * asbd.mBytesPerFrame
        var allocated: [AudioQueueBufferRef] = []
        for _ in 0..<numberOfBuffers {
            var buffer: AudioQueueBufferRef?
            if AudioQueueAllocateBuffer(newQueue, byteSize, &buffer) == noErr, let buffer {
                memset(buffer.pointee.mAudioData, 0, Int(byteSize))
                buffer.pointee.mAudioDataByteSize = byteSize
                AudioQueueEnqueueBuffer(newQueue, buffer, 0, nil)
                allocated.append(buffer)
            }
        }
        guard allocated.count == numberOfBuffers else {
            AudioQueueDispose(newQueue, true)
            stateLock.lock()
            lastErrorMessage = "AudioQueue buffers could not be allocated."
            stateLock.unlock()
            return
        }

        let startStatus = AudioQueueStart(newQueue, nil)
        guard startStatus == noErr else {
            AudioQueueDispose(newQueue, true)
            stateLock.lock()
            lastErrorMessage = "AudioQueue could not start (status \(startStatus))."
            stateLock.unlock()
            return
        }

        stateLock.lock()
        if queueGeneration == generation {
            queue = newQueue
            buffers = allocated
            ready = true
            activeDeviceID = deviceID
            outputInfoValue.isReady = true
            lastErrorMessage = nil
        } else {
            stateLock.unlock()
            AudioQueueStop(newQueue, true)
            AudioQueueDispose(newQueue, true)
            return
        }
        stateLock.unlock()
    }

    private func render(_ buffer: AudioQueueBufferRef, queue: AudioQueueRef) {
        stateLock.lock()
        let frames = Int(framesPerBuffer)
        let byteSize = UInt32(frames) * format.mBytesPerFrame
        stateLock.unlock()

        let output = buffer.pointee.mAudioData.assumingMemoryBound(to: Float.self)
        memset(buffer.pointee.mAudioData, 0, Int(byteSize))

        voiceLock.lock()
        if voices.isEmpty {
            voiceLock.unlock()
            buffer.pointee.mAudioDataByteSize = byteSize
            AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
            return
        }

        let kVolume = keyboardVolume
        let tVolume = trackpadVolume
        let now = CACurrentMediaTime()
        var finishedIndices: [Int] = []

        for index in voices.indices {
            if !voices[index].reportedPlayback {
                voices[index].reportedPlayback = true
                let latency = (now - voices[index].enqueuedAt) * 1000
                recentLatencies.append(latency)
                if recentLatencies.count > 64 { recentLatencies.removeFirst() }
            }

            let audio = voices[index].audio
            var position = voices[index].position
            let endFrame = voices[index].endFrame
            let rate = voices[index].rate
            let gain = voices[index].gain * (voices[index].source == .keyboard ? kVolume : tVolume)

            audio.samples.withUnsafeBufferPointer { source in
                guard let src = source.baseAddress else { return }
                var outFrame = 0
                while outFrame < frames {
                    let frame = Int(position)
                    if frame >= endFrame { break }
                    let next = min(frame + 1, endFrame - 1)
                    let fraction = Float(position - Double(frame))
                    let left = src[frame * 2] + (src[next * 2] - src[frame * 2]) * fraction
                    let right = src[frame * 2 + 1] + (src[next * 2 + 1] - src[frame * 2 + 1]) * fraction
                    output[outFrame * 2] += left * gain
                    output[outFrame * 2 + 1] += right * gain
                    position += rate
                    outFrame += 1
                }
            }
            voices[index].position = position
            if position >= Double(endFrame) { finishedIndices.append(index) }
        }

        if !finishedIndices.isEmpty {
            for index in finishedIndices.reversed() { voices.remove(at: index) }
        }
        voiceLock.unlock()

        // A soft limiter keeps many overlapping voices from clipping without
        // the hard edges of a clamp.
        let sampleCount = frames * 2
        for i in 0..<sampleCount {
            output[i] = tanhf(output[i])
        }

        buffer.pointee.mAudioDataByteSize = byteSize
        AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
    }

    private func setQueueDevice(_ queue: AudioQueueRef, deviceID: AudioDeviceID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid) == noErr,
              let deviceUID = uid?.takeRetainedValue() else { return }
        var uidRef: CFString = deviceUID
        let status = withUnsafePointer(to: &uidRef) { pointer in
            AudioQueueSetProperty(queue, kAudioQueueProperty_CurrentDevice, pointer, UInt32(MemoryLayout<CFString>.size))
        }
        if status != noErr {
            stateLock.lock()
            lastErrorMessage = "AudioQueue could not route to the selected output device (status \(status))."
            stateLock.unlock()
        }
    }

    // MARK: - CoreAudio queries

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return status == noErr && deviceID != 0 ? deviceID : nil
    }

    private func nominalSampleRate(_ deviceID: AudioDeviceID) -> Double? {
        var rate: Float64 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<Float64>.size)
        return AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rate) == noErr && rate > 0 ? rate : nil
    }

    private func queryOutputInfo(deviceID: AudioDeviceID?, sampleRate: Double) -> AudioOutputInfo {
        var info = AudioOutputInfo()
        info.sampleRate = sampleRate
        guard let deviceID else { return info }
        info.deviceName = deviceName(deviceID) ?? "Default output"

        var bufferFrames: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<UInt32>.size)
        _ = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &bufferFrames)
        info.hardwareBufferFrames = bufferFrames

        var deviceLatency: UInt32 = 0
        address.mSelector = kAudioDevicePropertyLatency
        size = UInt32(MemoryLayout<UInt32>.size)
        _ = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &deviceLatency)

        var safetyOffset: UInt32 = 0
        address.mSelector = kAudioDevicePropertySafetyOffset
        size = UInt32(MemoryLayout<UInt32>.size)
        _ = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &safetyOffset)

        guard sampleRate > 0 else { return info }
        let bufferMs = Double(bufferFrames) / sampleRate * 1000
        let deviceMs = Double(deviceLatency) / sampleRate * 1000
        let safetyMs = Double(safetyOffset) / sampleRate * 1000
        info.deviceLatencyMs = deviceMs
        info.safetyOffsetMs = safetyMs
        info.computedOutputLatencyMs = bufferMs + deviceMs + safetyMs
        return info
    }

    private func deviceName(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name) == noErr,
              let value = name?.takeRetainedValue() else { return nil }
        return value as String
    }
}

private let audioQueueCallback: AudioQueueOutputCallback = { userData, queue, buffer in
    guard let userData else { return }
    let engine = Unmanaged<AudioEngine>.fromOpaque(userData).takeUnretainedValue()
    engine.renderForCallback(buffer, queue: queue)
}

private extension AudioEngine {
    func renderForCallback(_ buffer: AudioQueueBufferRef, queue: AudioQueueRef) {
        render(buffer, queue: queue)
    }
}
