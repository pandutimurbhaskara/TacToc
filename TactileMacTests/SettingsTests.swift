import XCTest
@testable import TactileMac

final class SettingsTests: XCTestCase {
    func testDefaultsMatchProductBrief() {
        let settings = AppSettings()
        XCTAssertTrue(settings.keyboardEnabled)
        XCTAssertTrue(settings.trackpadEnabled)
        XCTAssertTrue(settings.hapticsEnabled)
        XCTAssertEqual(settings.keyboardPackID, "thock")
        XCTAssertEqual(settings.keyboardVolume, 0.65, accuracy: 0.0001)
        XCTAssertEqual(settings.trackpadPackID, "thock")
    }

    func testRoundTripPersistence() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let store = SettingsStore(paths: paths)
        var settings = AppSettings()
        settings.keyboardVolume = 0.31
        settings.trackpadVolume = 0.72
        settings.keyboardPackID = "clicky"
        settings.trackpadPackID = "linear"
        settings.hapticPattern = .levelChange
        settings.scrollMinimumIntervalMs = 73
        try store.save(settings)

        let result = store.load()
        XCTAssertNil(result.warning)
        XCTAssertEqual(result.settings.keyboardVolume, 0.31, accuracy: 0.0001)
        XCTAssertEqual(result.settings.trackpadVolume, 0.72, accuracy: 0.0001)
        XCTAssertEqual(result.settings.keyboardPackID, "clicky")
        XCTAssertEqual(result.settings.trackpadPackID, "linear")
        XCTAssertEqual(result.settings.hapticPattern, .levelChange)
        XCTAssertEqual(result.settings.scrollMinimumIntervalMs, 73, accuracy: 0.0001)
    }

    func testMissingFileUsesDefaultsWithoutWarning() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let result = SettingsStore(paths: paths).load()
        XCTAssertNil(result.warning)
        XCTAssertEqual(result.settings.keyboardVolume, 0.65, accuracy: 0.0001)
    }

    func testCorruptFileIsBackedUpAndDefaultsRestored() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let store = SettingsStore(paths: paths)
        try FileManager.default.createDirectory(at: paths.applicationSupport, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: store.fileURL)

        let result = store.load()
        XCTAssertNotNil(result.warning)
        XCTAssertEqual(result.settings.keyboardVolume, 0.65, accuracy: 0.0001)
        let backups = try FileManager.default.contentsOfDirectory(atPath: paths.applicationSupport.path)
            .filter { $0.hasPrefix("settings.invalid-") }
        XCTAssertEqual(backups.count, 1)
    }

    func testNewerSchemaIsRejectedRatherThanSilentlyOverwritten() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let store = SettingsStore(paths: paths)
        var settings = AppSettings()
        settings.schemaVersion = 99
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode(settings).write(to: store.fileURL)

        let result = store.load()
        XCTAssertNotNil(result.warning)
        XCTAssertEqual(result.settings.schemaVersion, AppSettings.currentSchemaVersion)
    }

    func testOutOfRangeValuesAreClampedOnSave() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let store = SettingsStore(paths: paths)
        var settings = AppSettings()
        settings.keyboardVolume = 4
        settings.trackpadVolume = -2
        settings.audioBufferFrames = 333
        settings.pitchVariation = 99
        try store.save(settings)
        let loaded = store.load().settings
        XCTAssertEqual(loaded.keyboardVolume, 1, accuracy: 0.0001)
        XCTAssertEqual(loaded.trackpadVolume, 0, accuracy: 0.0001)
        XCTAssertEqual(loaded.audioBufferFrames, 256)
        XCTAssertEqual(loaded.pitchVariation, 2, accuracy: 0.0001)
    }
}
