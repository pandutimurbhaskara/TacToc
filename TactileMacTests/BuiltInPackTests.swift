import XCTest
@testable import TactileMac

final class BuiltInPackTests: XCTestCase {
    func testEveryBundledPackIsValidAndLoads() throws {
        let root = try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("BuiltInPacks", isDirectory: true))
        let folders = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        XCTAssertEqual(Set(folders.map(\.lastPathComponent)), ["thock", "clicky", "linear", "soft"])

        for folder in folders {
            let manifestURL = folder.appendingPathComponent(PackManifest.manifestFileName)
            let (manifest, report) = try PackValidator.validateFile(manifestURL: manifestURL, root: folder)
            XCTAssertTrue(report.isValid, "\(folder.lastPathComponent): \(report.errors.joined(separator: "; "))")
            let loaded = try PackLoader().load(manifest: manifest, root: folder, sourceFormat: .tactilemac)
            XCTAssertNotNil(loaded.clips["key.down.default"], "\(folder.lastPathComponent) must have a default press")
            XCTAssertNotNil(loaded.clips["key.up.default"], "\(folder.lastPathComponent) must have a default release")
            XCTAssertNotNil(loaded.clips["trackpad.click.left"], "\(folder.lastPathComponent) must have a trackpad click")
            XCTAssertNotNil(loaded.clips["trackpad.scroll.up"], "\(folder.lastPathComponent) must have a scroll sound")
            XCTAssertGreaterThan(manifest.keyboardEventCount, 5)
            XCTAssertGreaterThan(manifest.trackpadEventCount, 3)
        }
    }
}
