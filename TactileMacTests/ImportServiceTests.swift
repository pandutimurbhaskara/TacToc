import XCTest
@testable import TactileMac

final class ImportServiceTests: XCTestCase {
    func testNativeImportCopiesFilesAndPreservesSource() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let source = Fixtures.url("NativePack")
        let originalManifest = try Data(contentsOf: source.appendingPathComponent(PackManifest.manifestFileName))

        let outcome = try PackImportService(paths: paths).importPack(from: source)
        XCTAssertEqual(outcome.sourceFormat, .tactilemac)
        XCTAssertEqual(outcome.pack.id, "fixture-native")
        let destination = paths.soundPacks.appendingPathComponent("fixture-native")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent(PackManifest.manifestFileName).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("sounds/tone.wav").path))

        let sourceAfter = try Data(contentsOf: source.appendingPathComponent(PackManifest.manifestFileName))
        XCTAssertEqual(sourceAfter, originalManifest, "Importing must never rewrite the source pack")
    }

    func testExtendedV2ImportWritesNormalizedManifestAndProvenanceWithoutRewritingConfig() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let source = Fixtures.url("ExtendedV2")
        let originalConfig = try Data(contentsOf: source.appendingPathComponent("config.json"))

        let outcome = try PackImportService(paths: paths).importPack(from: source)
        XCTAssertEqual(outcome.sourceFormat, .extendedV2)
        let destination = paths.soundPacks.appendingPathComponent("fixture-extended-v2")
        let configAfter = try Data(contentsOf: destination.appendingPathComponent("config.json"))
        XCTAssertEqual(configAfter, originalConfig, "config.json must be preserved verbatim")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("sound.ogg").path))

        let manifestData = try Data(contentsOf: destination.appendingPathComponent(PackManifest.manifestFileName))
        let manifest = try PackValidator.decodeManifest(data: manifestData)
        XCTAssertNotNil(manifest.events["key.down.KeyA"])
        XCTAssertNotNil(manifest.events["trackpad.click.left"])

        let provenanceData = try Data(contentsOf: destination.appendingPathComponent(PackProvenance.fileName))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let provenance = try decoder.decode(PackProvenance.self, from: provenanceData)
        XCTAssertEqual(provenance.sourceFormat, .extendedV2)
        XCTAssertEqual(provenance.sourceConfig, "config.json")
    }

    func testV1SingleImportProducesTimedSegments() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let outcome = try PackImportService(paths: paths).importPack(from: Fixtures.url("LegacyV1Single"))
        XCTAssertEqual(outcome.sourceFormat, .legacyV1)
        let destination = paths.soundPacks.appendingPathComponent("fixture-v1-single")
        let manifest = try PackValidator.decodeManifest(data: Data(contentsOf: destination.appendingPathComponent(PackManifest.manifestFileName)))
        XCTAssertEqual(manifest.events["key.down.KeyA"]?.first?.startMs, 0)
        XCTAssertEqual(manifest.events["key.down.KeyA"]?.first?.durationMs, 100)
    }

    func testTraversalPackIsRejected() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        XCTAssertThrowsError(try PackImportService(paths: paths).importPack(from: Fixtures.url("Invalid/Traversal")))
    }

    func testMissingAudioPackIsRejected() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        XCTAssertThrowsError(try PackImportService(paths: paths).importPack(from: Fixtures.url("Invalid/MissingFile")))
    }

    func testUnsupportedFuturePackIsRejected() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        XCTAssertThrowsError(try PackImportService(paths: paths).importPack(from: Fixtures.url("Invalid/UnsupportedVersion")))
    }

    func testSecondImportOfSameIDIsRejected() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let service = PackImportService(paths: paths)
        _ = try service.importPack(from: Fixtures.url("NativePack"))
        XCTAssertThrowsError(try service.importPack(from: Fixtures.url("NativePack"))) { error in
            XCTAssertTrue(error.localizedDescription.contains("already installed"))
        }
    }

    func testZipImportFindsNestedPackRoot() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let zip = temp.url.appendingPathComponent("pack.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", Fixtures.url("NativePack").path, zip.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let outcome = try PackImportService(paths: paths).importPack(from: zip)
        XCTAssertEqual(outcome.pack.id, "fixture-native")
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.soundPacks.appendingPathComponent("fixture-native/sounds/tone.wav").path))
    }
}
