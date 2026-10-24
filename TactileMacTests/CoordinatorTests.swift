import XCTest
@testable import TactileMac

private final class MockAudio: AudioPlaying {
    var isReady = true
    var acceptsEvents = true
    var plays: [[String]] = []
    var previews: [[String]] = []
    var volumes: (Float, Float) = (0, 0)

    func setVolumes(keyboard: Float, trackpad: Float) { volumes = (keyboard, trackpad) }
    func setActivePacks(keyboard: String, trackpad: String) {}
    func install(_ pack: LoadedPack) {}
    func unloadPack(id: String) {}
    func setBufferFrames(_ frames: Int) {}
    func play(source: AudioSource, eventKeys: [String], pitchVariation: Double) -> Bool {
        guard isReady, acceptsEvents else { return false }
        plays.append(eventKeys)
        return true
    }
    func preview(packID: String, eventKeys: [String], volume: Float) -> Bool {
        previews.append(eventKeys)
        return true
    }
    func latencySnapshot() -> (last: Double?, average: Double?) { (1.5, 2.5) }
}

private final class MockHaptics: HapticPlaying {
    var ticks: [HapticPatternName] = []
    func tick(_ pattern: HapticPatternName) { ticks.append(pattern) }
}

final class CoordinatorTests: XCTestCase {
    private var audio: MockAudio!
    private var haptics: MockHaptics!
    private var coordinator: FeedbackCoordinator!
    private var settings: AppSettings!
    private var secureInput = false

    override func setUp() {
        super.setUp()
        audio = MockAudio()
        haptics = MockHaptics()
        settings = AppSettings()
        settings.clickDebounceMs = 45
        settings.scrollMinimumIntervalMs = 42
        settings.preciseScrollOnly = true
        settings.includeMomentumScroll = false
        coordinator = FeedbackCoordinator(
            audio: audio,
            haptics: haptics,
            secureInputProvider: { [weak self] in self?.secureInput ?? false },
            clock: { 0 }
        )
        coordinator.apply(settings)
    }

    func testKeyDownKeyUpAndDuplicateSuppression() {
        let down = coordinator.handle(.keyDown(code: 0, isRepeat: false, timestamp: 1))
        XCTAssertTrue(down.soundPlayed)
        XCTAssertEqual(audio.plays.last?.first, "key.down.KeyA")

        let duplicate = coordinator.handle(.keyDown(code: 0, isRepeat: false, timestamp: 1.1))
        XCTAssertTrue(duplicate.dropped)
        XCTAssertEqual(audio.plays.count, 1)

        let up = coordinator.handle(.keyUp(code: 0, timestamp: 1.2))
        XCTAssertTrue(up.soundPlayed)
        XCTAssertEqual(audio.plays.last?.first, "key.up.KeyA")

        let strayUp = coordinator.handle(.keyUp(code: 0, timestamp: 1.3))
        XCTAssertTrue(strayUp.dropped)
    }

    func testKeyRepeatIsSuppressedByDefaultAndCanBeEnabled() {
        _ = coordinator.handle(.keyDown(code: 0, isRepeat: false, timestamp: 1))
        let repeated = coordinator.handle(.keyDown(code: 0, isRepeat: true, timestamp: 1.1))
        XCTAssertTrue(repeated.dropped)
        XCTAssertEqual(audio.plays.count, 1)

        settings.playKeyRepeatSounds = true
        coordinator.apply(settings)
        let enabled = coordinator.handle(.keyDown(code: 0, isRepeat: true, timestamp: 1.2))
        XCTAssertTrue(enabled.soundPlayed)
        XCTAssertEqual(audio.plays.count, 2)
    }

    func testSecureInputDropsKeyboardFeedback() {
        secureInput = true
        let result = coordinator.handle(.keyDown(code: 0, isRepeat: false, timestamp: 1))
        XCTAssertTrue(result.dropped)
        XCTAssertTrue(audio.plays.isEmpty)
    }

    func testHapticsCanWorkWithKeyboardAudioDisabled() {
        settings.keyboardEnabled = false
        settings.hapticsEnabled = true
        settings.hapticOnKeyboard = true
        coordinator.apply(settings)
        let result = coordinator.handle(.keyDown(code: 0, isRepeat: false, timestamp: 1))
        XCTAssertFalse(result.soundPlayed)
        XCTAssertTrue(result.hapticPlayed)
        XCTAssertEqual(haptics.ticks.count, 1)
    }

    func testModifierReleaseHonoursPlayReleaseSetting() {
        _ = coordinator.handle(.modifierChanged(code: 55, isDown: true, timestamp: 1))
        XCTAssertEqual(haptics.ticks.count, 0)
        XCTAssertEqual(audio.plays.count, 1)
        _ = coordinator.handle(.modifierChanged(code: 55, isDown: false, timestamp: 1.1))
        XCTAssertEqual(audio.plays.count, 2)

        settings.playKeyUpSounds = false
        coordinator.apply(settings)
        _ = coordinator.handle(.modifierChanged(code: 56, isDown: true, timestamp: 2))
        _ = coordinator.handle(.modifierChanged(code: 56, isDown: false, timestamp: 2.1))
        XCTAssertEqual(audio.plays.count, 3)
    }

    func testClickDebounceAndHapticIndependence() {
        let first = coordinator.handle(.mouseButton(button: .left, isDown: true, timestamp: 5.0))
        XCTAssertTrue(first.soundPlayed)
        XCTAssertTrue(first.hapticPlayed)
        let bounced = coordinator.handle(.mouseButton(button: .left, isDown: true, timestamp: 5.02))
        XCTAssertTrue(bounced.dropped)
        let later = coordinator.handle(.mouseButton(button: .left, isDown: true, timestamp: 5.1))
        XCTAssertTrue(later.soundPlayed)

        settings.trackpadEnabled = false
        settings.hapticsEnabled = true
        settings.hapticOnTrackpadClicks = true
        coordinator.apply(settings)
        let hapticOnly = coordinator.handle(.mouseButton(button: .right, isDown: true, timestamp: 6.0))
        XCTAssertFalse(hapticOnly.soundPlayed)
        XCTAssertTrue(hapticOnly.hapticPlayed)
    }

    func testScrollThresholdRateLimitAndMomentumFilter() {
        let nonPrecise = coordinator.handle(.scroll(deltaY: 9, isPrecise: false, isMomentum: false, timestamp: 10.0))
        XCTAssertTrue(nonPrecise.dropped)
        let momentum = coordinator.handle(.scroll(deltaY: 9, isPrecise: true, isMomentum: true, timestamp: 10.0))
        XCTAssertTrue(momentum.dropped)
        XCTAssertTrue(audio.plays.isEmpty)

        let first = coordinator.handle(.scroll(deltaY: 9, isPrecise: true, isMomentum: false, timestamp: 10.0))
        XCTAssertTrue(first.soundPlayed)
        XCTAssertEqual(audio.plays.last?.first, "trackpad.scroll.up")

        let tooSoon = coordinator.handle(.scroll(deltaY: 9, isPrecise: true, isMomentum: false, timestamp: 10.01))
        XCTAssertTrue(tooSoon.dropped)
        XCTAssertEqual(audio.plays.count, 1)

        let later = coordinator.handle(.scroll(deltaY: 9, isPrecise: true, isMomentum: false, timestamp: 10.1))
        XCTAssertTrue(later.soundPlayed)
        XCTAssertEqual(audio.plays.count, 2)

        let reverse = coordinator.handle(.scroll(deltaY: -9, isPrecise: true, isMomentum: false, timestamp: 10.2))
        XCTAssertTrue(reverse.soundPlayed)
        XCTAssertEqual(audio.plays.last?.first, "trackpad.scroll.down")
    }

    func testScrollHapticsAreRateLimitedSeparately() {
        settings.hapticOnScroll = true
        settings.hapticMaterial = .softGrid
        coordinator.apply(settings)
        _ = coordinator.handle(.scroll(deltaY: 9, isPrecise: true, isMomentum: false, timestamp: 20.0))
        _ = coordinator.handle(.scroll(deltaY: 9, isPrecise: true, isMomentum: false, timestamp: 20.1))
        XCTAssertEqual(haptics.ticks.count, 2)
        _ = coordinator.handle(.scroll(deltaY: 9, isPrecise: true, isMomentum: false, timestamp: 20.3))
        XCTAssertEqual(haptics.ticks.count, 3)
    }

    func testPointerMovementProducesMaterialPulsesAndRateLimits() {
        settings.hapticMaterial = .softGrid
        settings.hapticOnPointerMovement = true
        settings.hapticsEnabled = true
        coordinator.apply(settings)

        _ = coordinator.handle(.pointerMoved(x: 0, y: 0, timestamp: 1.0))
        XCTAssertEqual(haptics.ticks.count, 0)

        let first = coordinator.handle(.pointerMoved(x: 30, y: 0, timestamp: 1.1))
        XCTAssertTrue(first.hapticPlayed)
        XCTAssertEqual(haptics.ticks.count, 1)

        let tooSoon = coordinator.handle(.pointerMoved(x: 60, y: 0, timestamp: 1.12))
        XCTAssertTrue(tooSoon.dropped)
        XCTAssertEqual(haptics.ticks.count, 1)

        let later = coordinator.handle(.pointerMoved(x: 90, y: 0, timestamp: 1.2))
        XCTAssertTrue(later.hapticPlayed)
        XCTAssertEqual(haptics.ticks.count, 2)
    }

    func testPointerMovementCanBeDisabled() {
        settings.hapticOnPointerMovement = false
        coordinator.apply(settings)
        _ = coordinator.handle(.pointerMoved(x: 0, y: 0, timestamp: 1.0))
        let result = coordinator.handle(.pointerMoved(x: 40, y: 0, timestamp: 1.1))
        XCTAssertTrue(result.dropped)
        XCTAssertEqual(haptics.ticks.count, 0)
    }

    func testScrollHapticsCanRunWithTrackpadAudioDisabled() {
        settings.trackpadEnabled = false
        settings.trackpadScrollEnabled = false
        settings.hapticOnScroll = true
        settings.hapticMaterial = .softGrid
        coordinator.apply(settings)
        let result = coordinator.handle(.scroll(deltaY: 9, isPrecise: true, isMomentum: false, timestamp: 30.0))
        XCTAssertFalse(result.soundPlayed)
        XCTAssertTrue(result.hapticPlayed)
        XCTAssertEqual(haptics.ticks.count, 1)
    }

    func testResetClearsPressedState() {
        _ = coordinator.handle(.keyDown(code: 0, isRepeat: false, timestamp: 1))
        coordinator.resetTransientState()
        let freshDown = coordinator.handle(.keyDown(code: 0, isRepeat: false, timestamp: 1.1))
        XCTAssertTrue(freshDown.soundPlayed)
    }
}
