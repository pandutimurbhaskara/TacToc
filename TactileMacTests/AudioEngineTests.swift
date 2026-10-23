import XCTest
@testable import TactileMac

final class AudioEngineTests: XCTestCase {
    func testEngineStartsLoadsAPackAndMeasuresSchedulingLatency() throws {
        let engine = AudioEngine(bufferFrames: 256)
        try XCTSkipIf(!engine.isReady, "No audio output device available: \(engine.lastError ?? "unknown")")
        addTeardownBlock { engine.setBufferFrames(256) }

        let root = Fixtures.url("NativePack")
        let manifestURL = root.appendingPathComponent(PackManifest.manifestFileName)
        let (manifest, report) = try PackValidator.validateFile(manifestURL: manifestURL, root: root)
        XCTAssertTrue(report.isValid)
        let loaded = try PackLoader().load(manifest: manifest, root: root, sourceFormat: .tactilemac)
        engine.install(loaded)
        engine.setActivePacks(keyboard: "fixture-native", trackpad: "fixture-native")
        engine.setVolumes(keyboard: 0.1, trackpad: 0.1)
        XCTAssertEqual(engine.outputInfo.sampleRate, 44_100, accuracy: 48_000)

        XCTAssertTrue(engine.play(source: .keyboard, eventKeys: ["key.down.default"], pitchVariation: 0))
        let mixed = expectation(description: "audio callback mixed the voice")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { mixed.fulfill() }
        wait(for: [mixed], timeout: 2)

        let latency = engine.latencySnapshot()
        XCTAssertNotNil(latency.last, "The audio callback should have mixed the voice")
        XCTAssertGreaterThanOrEqual(latency.last ?? -1, 0)
        XCTAssertLessThan(latency.last ?? 999, 250, "Event-to-first-mix latency should be well below 250 ms")
        print("AUDIO_ENGINE_MEASUREMENT device=\(engine.outputInfo.deviceName) rate=\(engine.outputInfo.sampleRate) hardwareBuffer=\(engine.outputInfo.hardwareBufferFrames) reportedOutputLatency=\(engine.outputInfo.computedOutputLatencyMs)ms eventToFirstMix=\(latency.last ?? -1)ms")

        engine.rebuild()
        XCTAssertTrue(engine.isReady, "The engine should rebuild after a simulated device reset")
    }

    func testOggVorbisClipReachesTheAudioQueueAndPlays() throws {
        let engine = AudioEngine(bufferFrames: 256)
        try XCTSkipIf(!engine.isReady, "No audio output device available: \(engine.lastError ?? "unknown")")

        let root = Fixtures.url("ExtendedV2")
        let conversion = try LegacyPackImporter.convert(
            configData: try Fixtures.configData("ExtendedV2"),
            packRoot: root,
            fallbackID: "ogg-engine-test"
        )
        let loaded = try PackLoader().load(manifest: conversion.manifest, root: root, sourceFormat: conversion.sourceFormat)
        XCTAssertEqual(loaded.clips["key.down.KeyA"]?.first?.sample.sampleRate, 44_100)
        engine.install(loaded)
        engine.setActivePacks(keyboard: "fixture-extended-v2", trackpad: "fixture-extended-v2")
        engine.setVolumes(keyboard: 0.1, trackpad: 0.1)
        XCTAssertTrue(engine.play(source: .keyboard, eventKeys: ["key.down.KeyA"], pitchVariation: 0))

        let mixed = expectation(description: "OGG voice mixed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { mixed.fulfill() }
        wait(for: [mixed], timeout: 2)
        let latency = engine.latencySnapshot()
        XCTAssertNotNil(latency.last)
        print("OGG_ENGINE_MEASUREMENT eventToFirstMix=\(latency.last ?? -1)ms")
    }
}
