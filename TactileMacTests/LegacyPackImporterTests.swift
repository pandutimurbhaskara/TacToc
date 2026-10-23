import XCTest
@testable import TactileMac

final class LegacyPackImporterTests: XCTestCase {
    func testLegacyV1SingleUsesStartPlusDurationAndSkipsNull() throws {
        let root = Fixtures.url("LegacyV1Single")
        let data = try Fixtures.configData("LegacyV1Single")
        let conversion = try LegacyPackImporter.convert(configData: data, packRoot: root, fallbackID: "v1-single")
        XCTAssertEqual(conversion.sourceFormat, .legacyV1)
        XCTAssertEqual(conversion.manifest.id, "fixture-v1-single")
        XCTAssertEqual(conversion.manifest.events["key.down.KeyA"]?.first?.startMs, 0)
        XCTAssertEqual(conversion.manifest.events["key.down.KeyA"]?.first?.durationMs, 100)
        XCTAssertEqual(conversion.manifest.events["key.down.Space"]?.first?.startMs, 100)
        XCTAssertEqual(conversion.manifest.events["key.down.Backspace"]?.first?.startMs, 200)
        XCTAssertNil(conversion.manifest.events["key.down.Enter"])
        XCTAssertNil(conversion.manifest.events["key.up.KeyA"])
    }

    func testLegacyV1MultiDoesNotInventAFallback() throws {
        let root = Fixtures.url("LegacyV1Multi")
        let data = try Fixtures.configData("LegacyV1Multi")
        let conversion = try LegacyPackImporter.convert(configData: data, packRoot: root, fallbackID: "v1-multi")
        XCTAssertEqual(conversion.sourceFormat, .legacyV1)
        XCTAssertEqual(conversion.manifest.events["key.down.KeyA"]?.first?.file, "a.wav")
        XCTAssertEqual(conversion.manifest.events["key.down.Space"]?.first?.file, "space.wav")
        XCTAssertNil(conversion.manifest.events["key.down.KeyB"])
        XCTAssertNil(conversion.manifest.events["key.up.KeyA"])
    }

    func testLegacyV2FillsFallbacksAndKeepsKeyUp() throws {
        let root = Fixtures.url("LegacyV2Multi")
        let data = try Fixtures.configData("LegacyV2Multi")
        let conversion = try LegacyPackImporter.convert(configData: data, packRoot: root, fallbackID: "v2")
        XCTAssertEqual(conversion.sourceFormat, .legacyV2)
        XCTAssertEqual(conversion.manifest.events["key.down.KeyA"]?.first?.file, "a.wav")
        XCTAssertEqual(conversion.manifest.events["key.down.KeyB"]?.first?.file, "fallback.wav")
        XCTAssertEqual(conversion.manifest.events["key.up.KeyB"]?.first?.file, "release.wav")
        XCTAssertEqual(conversion.manifest.events["key.up.KeyA"]?.first?.file, "a-up.wav")
        XCTAssertNil(conversion.manifest.events["key.down.KeyA"]?.first?.durationMs)
    }

    func testLegacyV2SingleSupportsTimedKeyUpSegments() throws {
        let root = Fixtures.url("LegacyV2Single")
        let data = try Fixtures.configData("LegacyV2Single")
        let conversion = try LegacyPackImporter.convert(configData: data, packRoot: root, fallbackID: "v2-single")
        XCTAssertEqual(conversion.sourceFormat, .legacyV2)
        let down = try XCTUnwrap(conversion.manifest.events["key.down.KeyA"]?.first)
        XCTAssertEqual(down.file, "tone.wav")
        XCTAssertEqual(down.startMs, 0)
        XCTAssertEqual(down.durationMs, 100)
        let up = try XCTUnwrap(conversion.manifest.events["key.up.KeyA"]?.first)
        XCTAssertEqual(up.file, "tone.wav")
        XCTAssertEqual(up.startMs, 100)
        XCTAssertEqual(up.durationMs, 100)
    }

    func testLegacyV2FilenameRangeExpandsIntoVariations() throws {
        let root = Fixtures.url("LegacyV2Range")
        let data = try Fixtures.configData("LegacyV2Range")
        let conversion = try LegacyPackImporter.convert(configData: data, packRoot: root, fallbackID: "v2-range")
        let exact = try XCTUnwrap(conversion.manifest.events["key.down.KeyA"])
        XCTAssertEqual(exact.count, 1, "An explicit key file should win over the fallback")
        XCTAssertEqual(exact.first?.file, "press/tick_0.wav")
        let fallback = try XCTUnwrap(conversion.manifest.events["key.down.KeyB"])
        XCTAssertEqual(fallback.count, 3, "The {{0-2}} range should expand to all three existing files")
        XCTAssertEqual(Set(fallback.map(\.file)), ["press/tick_0.wav", "press/tick_1.wav", "press/tick_2.wav"])
        XCTAssertEqual(conversion.manifest.events["key.up.KeyB"]?.first?.file, "release.wav")
    }

    func testExtendedV2ConvertsStartEndToStartDurationAndMapsMouse() throws {
        let root = Fixtures.url("ExtendedV2")
        let data = try Fixtures.configData("ExtendedV2")
        let conversion = try LegacyPackImporter.convert(configData: data, packRoot: root, fallbackID: "extended-v2")
        XCTAssertEqual(conversion.sourceFormat, .extendedV2)
        let keyA = try XCTUnwrap(conversion.manifest.events["key.down.KeyA"])
        XCTAssertEqual(keyA.count, 2)
        XCTAssertEqual(keyA[0].startMs, 0)
        XCTAssertEqual(keyA[0].durationMs, 100)
        XCTAssertEqual(keyA[1].startMs, 100)
        XCTAssertEqual(keyA[1].durationMs, 80)
        XCTAssertNotNil(conversion.manifest.events["key.down.Space"])
        XCTAssertNotNil(conversion.manifest.events["trackpad.click.left"])
        XCTAssertEqual(conversion.manifest.recommendedVolume, 0.9)
        XCTAssertEqual(conversion.manifest.pitchVariation, 0.2)
    }

    func testExtendedV2MouseFixtureMapsWheelAndButtons() throws {
        let root = Fixtures.url("ExtendedV2Mouse")
        let data = try Fixtures.configData("ExtendedV2Mouse")
        let conversion = try LegacyPackImporter.convert(configData: data, packRoot: root, fallbackID: "extended-v2-mouse")
        XCTAssertNotNil(conversion.manifest.events["trackpad.click.left"])
        XCTAssertNotNil(conversion.manifest.events["trackpad.click.right"])
        XCTAssertNotNil(conversion.manifest.events["trackpad.scroll.up"])
        XCTAssertEqual(conversion.manifest.id, "extended-v2-mouse")
    }

    func testUnsupportedFutureVersionIsRejectedWithMessage() throws {
        let root = Fixtures.url("Invalid/UnsupportedVersion")
        let data = try Fixtures.configData("Invalid/UnsupportedVersion")
        XCTAssertThrowsError(try LegacyPackImporter.convert(configData: data, packRoot: root, fallbackID: "future")) { error in
            XCTAssertTrue(error.localizedDescription.contains("requires a newer extended V2"))
        }
    }

    func testMalformedJSONIsRejected() throws {
        let root = Fixtures.url("Invalid/Malformed")
        let data = try Fixtures.configData("Invalid/Malformed")
        XCTAssertThrowsError(try LegacyPackImporter.convert(configData: data, packRoot: root, fallbackID: "broken")) { error in
            XCTAssertTrue(error.localizedDescription.contains("invalid JSON"))
        }
    }

    func testMissingReferencedAudioIsReported() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        try writeJSON([
            "config_version": "2",
            "name": "Missing audio",
            "author": "Tests",
            "definition_method": "single",
            "audio_file": "missing.wav",
            "definitions": ["KeyA": ["timing": [[0, 50]]]]
        ], to: temp.url.appendingPathComponent("config.json"))
        let data = try Data(contentsOf: temp.url.appendingPathComponent("config.json"))
        XCTAssertThrowsError(try LegacyPackImporter.convert(configData: data, packRoot: temp.url, fallbackID: "missing")) { error in
            XCTAssertTrue(error.localizedDescription.contains("missing.wav"))
        }
    }

    func testUnsupportedExtendedV2KeyIsWarnedNotSilentlyDropped() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        try FileManager.default.copyItem(at: Fixtures.url("Audio/tone.wav"), to: temp.url.appendingPathComponent("tone.wav"))
        try writeJSON([
            "config_version": 2,
            "name": "Unknown key",
            "author": "Tests",
            "definition_method": "single",
            "audio_file": "tone.wav",
            "definitions": [
                "KeyA": ["timing": [[0, 50]]],
                "NotARealKey": ["timing": [[0, 50]]]
            ]
        ], to: temp.url.appendingPathComponent("config.json"))
        let conversion = try LegacyPackImporter.convert(
            configData: try Data(contentsOf: temp.url.appendingPathComponent("config.json")),
            packRoot: temp.url,
            fallbackID: "unknown"
        )
        XCTAssertNotNil(conversion.manifest.events["key.down.KeyA"])
        XCTAssertTrue(conversion.warnings.contains { $0.contains("NotARealKey") })
    }

    func testExtendedV2DirectTimingArrayIsAccepted() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        try FileManager.default.copyItem(at: Fixtures.url("Audio/tone.wav"), to: temp.url.appendingPathComponent("tone.wav"))
        try writeJSON([
            "config_version": 2,
            "name": "Direct timing",
            "author": "Tests",
            "definition_method": "single",
            "audio_file": "tone.wav",
            "definitions": ["KeyA": [[10, 60]]]
        ], to: temp.url.appendingPathComponent("config.json"))
        let conversion = try LegacyPackImporter.convert(
            configData: try Data(contentsOf: temp.url.appendingPathComponent("config.json")),
            packRoot: temp.url,
            fallbackID: "direct"
        )
        let clip = try XCTUnwrap(conversion.manifest.events["key.down.KeyA"]?.first)
        XCTAssertEqual(clip.startMs, 10)
        XCTAssertEqual(clip.durationMs, 50)
    }
}
