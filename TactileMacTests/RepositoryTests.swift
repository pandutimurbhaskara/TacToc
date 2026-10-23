import XCTest
@testable import TactileMac

final class RepositoryTests: XCTestCase {
    func testBuiltInAndUserPacksAreScannedAndDuplicateIDsAreFlagged() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let builtInRoot = temp.url.appendingPathComponent("BuiltIn", isDirectory: true)
        let builtInPack = builtInRoot.appendingPathComponent("fixture-native", isDirectory: true)
        try FileManager.default.createDirectory(at: builtInRoot, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Fixtures.url("NativePack"), to: builtInPack)

        let repository = PackRepository(paths: paths, builtInRoot: builtInRoot)
        var scan = repository.scan()
        XCTAssertEqual(scan.packs.count, 1)
        XCTAssertTrue(scan.packs[0].isBuiltIn)
        XCTAssertEqual(scan.packs[0].id, "fixture-native")
        XCTAssertNil(scan.packs[0].issue)

        let userCopy = paths.soundPacks.appendingPathComponent("fixture-native")
        try FileManager.default.copyItem(at: Fixtures.url("NativePack"), to: userCopy)
        scan = repository.scan()
        XCTAssertEqual(scan.packs.count, 2)
        let user = try XCTUnwrap(scan.packs.first { !$0.isBuiltIn })
        XCTAssertNotNil(user.issue)
        XCTAssertTrue(user.issue?.contains("already uses") == true)
    }

    func testRawLegacyFolderIsNotListedAsInstalled() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let builtInRoot = temp.url.appendingPathComponent("BuiltIn", isDirectory: true)
        try FileManager.default.createDirectory(at: builtInRoot, withIntermediateDirectories: true)
        let raw = paths.soundPacks.appendingPathComponent("raw-legacy")
        try FileManager.default.copyItem(at: Fixtures.url("LegacyV1Single"), to: raw)

        let scan = PackRepository(paths: paths, builtInRoot: builtInRoot).scan()
        XCTAssertTrue(scan.packs.isEmpty)
        XCTAssertTrue(scan.warnings.contains { $0.contains("raw-legacy") && $0.contains("Import") })
    }
}
