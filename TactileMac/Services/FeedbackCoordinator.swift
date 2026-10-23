import Carbon
import Foundation
import QuartzCore

struct FeedbackResult {
    var soundPlayed = false
    var hapticPlayed = false
    var dropped = false
    var reason: String?
}

final class FeedbackCoordinator {
    private struct Config {
        var keyboardEnabled = true
        var trackpadEnabled = true
        var playKeyUpSounds = true
        var playModifierSounds = true
        var playKeyRepeatSounds = false
        var trackpadClicksEnabled = true
        var trackpadScrollEnabled = true
        var preciseScrollOnly = true
        var includeMomentumScroll = false
        var scrollMinimumInterval: TimeInterval = 0.042
        var clickDebounce: TimeInterval = 0.045
        var pitchVariation: Double = 0.08
        var hapticsEnabled = true
        var hapticOnKeyboard = false
        var hapticOnTrackpadClicks = true
        var hapticOnScroll = false
        var hapticPattern: HapticPatternName = .generic
        var volumes = (keyboard: Float(0.65), trackpad: Float(0.55))
    }

    private weak var audio: AudioPlaying?
    private weak var haptics: HapticPlaying?
    private let lock = NSLock()
    private var config = Config()
    private var pressedKeys = Set<Int64>()
    private var lastClickTimes: [MouseButtonName: TimeInterval] = [:]
    private var scrollAccumulator: Double = 0
    private var scrollDirection: String?
    private var lastScrollSound: TimeInterval = 0
    private var lastScrollHaptic: TimeInterval = 0
    private var secureInputProvider: () -> Bool
    private var clock: () -> TimeInterval

    init(
        audio: AudioPlaying,
        haptics: HapticPlaying,
        secureInputProvider: @escaping () -> Bool = { IsSecureEventInputEnabled() },
        clock: @escaping () -> TimeInterval = { CACurrentMediaTime() }
    ) {
        self.audio = audio
        self.haptics = haptics
        self.secureInputProvider = secureInputProvider
        self.clock = clock
    }

    func apply(_ settings: AppSettings) {
        lock.lock()
        config = Config(
            keyboardEnabled: settings.keyboardEnabled,
            trackpadEnabled: settings.trackpadEnabled,
            playKeyUpSounds: settings.playKeyUpSounds,
            playModifierSounds: settings.playModifierSounds,
            playKeyRepeatSounds: settings.playKeyRepeatSounds,
            trackpadClicksEnabled: settings.trackpadClicksEnabled,
            trackpadScrollEnabled: settings.trackpadScrollEnabled,
            preciseScrollOnly: settings.preciseScrollOnly,
            includeMomentumScroll: settings.includeMomentumScroll,
            scrollMinimumInterval: settings.scrollMinimumIntervalMs / 1000,
            clickDebounce: settings.clickDebounceMs / 1000,
            pitchVariation: settings.pitchVariation,
            hapticsEnabled: settings.hapticsEnabled,
            hapticOnKeyboard: settings.hapticOnKeyboard,
            hapticOnTrackpadClicks: settings.hapticOnTrackpadClicks,
            hapticOnScroll: settings.hapticOnScroll,
            hapticPattern: settings.hapticPattern,
            volumes: (Float(settings.keyboardVolume), Float(settings.trackpadVolume))
        )
        lock.unlock()
        audio?.setVolumes(keyboard: Float(settings.keyboardVolume), trackpad: Float(settings.trackpadVolume))
    }

    func handle(_ event: NormalizedInputEvent) -> FeedbackResult {
        switch event {
        case .keyDown(let code, let isRepeat, let timestamp):
            return handleKey(code: code, isDown: true, isRepeat: isRepeat, timestamp: timestamp)
        case .keyUp(let code, let timestamp):
            return handleKey(code: code, isDown: false, isRepeat: false, timestamp: timestamp)
        case .modifierChanged(let code, let isDown, let timestamp):
            return handleModifier(code: code, isDown: isDown, timestamp: timestamp)
        case .mouseButton(let button, let isDown, let timestamp):
            return handleMouse(button: button, isDown: isDown, timestamp: timestamp)
        case .scroll(let deltaY, let isPrecise, let isMomentum, let timestamp):
            return handleScroll(deltaY: deltaY, isPrecise: isPrecise, isMomentum: isMomentum, timestamp: timestamp)
        }
    }

    // MARK: - Keyboard

    private func handleKey(code: Int64, isDown: Bool, isRepeat: Bool, timestamp: TimeInterval) -> FeedbackResult {
        guard let descriptor = KeyCodeMap.descriptor(for: code) else {
            return FeedbackResult(dropped: true, reason: "Unknown key code")
        }
        lock.lock()
        let cfg = config
        var result = FeedbackResult()
        if isDown {
            if pressedKeys.contains(code) && !isRepeat {
                lock.unlock()
                return FeedbackResult(dropped: true, reason: "Duplicate key down")
            }
            pressedKeys.insert(code)
            if isRepeat && !cfg.playKeyRepeatSounds {
                lock.unlock()
                return FeedbackResult(dropped: true, reason: "Key repeat suppressed")
            }
        } else {
            let wasPressed = pressedKeys.remove(code) != nil
            if !wasPressed {
                lock.unlock()
                return FeedbackResult(dropped: true, reason: "Key up without a matching down")
            }
        }
        let telemetrySuppressed = secureInputProvider()
        lock.unlock()

        if telemetrySuppressed { return FeedbackResult(dropped: true, reason: "Secure Event Input is active") }

        let wantsAudio = cfg.keyboardEnabled && (isDown || cfg.playKeyUpSounds)
        let wantsHaptic = isDown && cfg.hapticsEnabled && cfg.hapticOnKeyboard
        if wantsAudio {
            let keys = isDown ? descriptor.downEvents : descriptor.upEvents
            result.soundPlayed = audio?.play(source: .keyboard, eventKeys: keys, pitchVariation: cfg.pitchVariation) ?? false
        }
        if wantsHaptic {
            haptics?.tick(cfg.hapticPattern)
            result.hapticPlayed = true
        }
        if !wantsAudio && !wantsHaptic { result.dropped = true }
        return result
    }

    private func handleModifier(code: Int64, isDown: Bool, timestamp: TimeInterval) -> FeedbackResult {
        guard let descriptor = KeyCodeMap.descriptor(for: code) else {
            return FeedbackResult(dropped: true, reason: "Unknown modifier")
        }
        lock.lock()
        let cfg = config
        lock.unlock()
        if secureInputProvider() { return FeedbackResult(dropped: true, reason: "Secure Event Input is active") }
        var result = FeedbackResult()
        let wantsAudio = cfg.keyboardEnabled && cfg.playModifierSounds && (isDown || cfg.playKeyUpSounds)
        if wantsAudio {
            let keys = isDown ? descriptor.downEvents : descriptor.upEvents
            result.soundPlayed = audio?.play(source: .keyboard, eventKeys: keys, pitchVariation: cfg.pitchVariation) ?? false
        }
        if isDown && cfg.hapticsEnabled && cfg.hapticOnKeyboard {
            haptics?.tick(cfg.hapticPattern)
            result.hapticPlayed = true
        }
        if !wantsAudio && !result.hapticPlayed { result.dropped = true }
        return result
    }

    // MARK: - Trackpad

    private func handleMouse(button: MouseButtonName, isDown: Bool, timestamp: TimeInterval) -> FeedbackResult {
        guard isDown else { return FeedbackResult(dropped: true, reason: "Button release") }
        guard button != .other else { return FeedbackResult(dropped: true, reason: "Auxiliary button ignored") }
        lock.lock()
        let cfg = config
        if let last = lastClickTimes[button], timestamp - last < cfg.clickDebounce {
            lock.unlock()
            return FeedbackResult(dropped: true, reason: "Click debounced")
        }
        lastClickTimes[button] = timestamp
        lock.unlock()

        var result = FeedbackResult()
        if cfg.trackpadEnabled && cfg.trackpadClicksEnabled {
            result.soundPlayed = audio?.play(source: .trackpad, eventKeys: PackEvent.click(button), pitchVariation: cfg.pitchVariation) ?? false
        }
        if cfg.hapticsEnabled && cfg.hapticOnTrackpadClicks {
            haptics?.tick(cfg.hapticPattern)
            result.hapticPlayed = true
        }
        if !result.soundPlayed && !result.hapticPlayed { result.dropped = true }
        return result
    }

    private func handleScroll(deltaY: Double, isPrecise: Bool, isMomentum: Bool, timestamp: TimeInterval) -> FeedbackResult {
        guard deltaY != 0 else { return FeedbackResult(dropped: true, reason: "Empty scroll") }
        lock.lock()
        let cfg = config
        if cfg.preciseScrollOnly && !isPrecise {
            lock.unlock()
            return FeedbackResult(dropped: true, reason: "Non-precise scroll ignored")
        }
        if isMomentum && !cfg.includeMomentumScroll {
            lock.unlock()
            return FeedbackResult(dropped: true, reason: "Momentum scroll ignored")
        }
        let direction = deltaY > 0 ? "up" : "down"
        if scrollDirection != direction {
            scrollDirection = direction
            scrollAccumulator = 0
        }
        let stride = isPrecise ? 8.0 : 1.0
        scrollAccumulator += abs(deltaY)
        if scrollAccumulator < stride {
            lock.unlock()
            return FeedbackResult(dropped: true, reason: "Scroll accumulator below threshold")
        }
        if timestamp - lastScrollSound < cfg.scrollMinimumInterval {
            scrollAccumulator = min(scrollAccumulator, stride)
            lock.unlock()
            return FeedbackResult(dropped: true, reason: "Scroll rate limited")
        }
        lastScrollSound = timestamp
        scrollAccumulator = 0
        let canHaptic = cfg.hapticsEnabled && cfg.hapticOnScroll && timestamp - lastScrollHaptic >= 0.12
        if canHaptic { lastScrollHaptic = timestamp }
        lock.unlock()

        var result = FeedbackResult()
        if cfg.trackpadEnabled && cfg.trackpadScrollEnabled {
            result.soundPlayed = audio?.play(source: .trackpad, eventKeys: PackEvent.scroll(direction: direction), pitchVariation: cfg.pitchVariation) ?? false
        }
        if canHaptic {
            haptics?.tick(cfg.hapticPattern)
            result.hapticPlayed = true
        }
        if !result.soundPlayed && !result.hapticPlayed { result.dropped = true }
        return result
    }

    func resetTransientState() {
        lock.lock()
        pressedKeys.removeAll()
        lastClickTimes.removeAll()
        scrollAccumulator = 0
        scrollDirection = nil
        lock.unlock()
    }
}
