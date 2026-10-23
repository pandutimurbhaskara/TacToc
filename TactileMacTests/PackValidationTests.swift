import XCTest
@testable import TactileMac

final class PackValidationTests: XCTestCase {
    func testNativeFixtureIsValidAndLoads() throws {
        let root = Fixtures.url("NativePack")
        let manifestURL = root.appendingPathComponent(PackManifest.manifestFileName)
        let (manifest, report) = try PackValidator.validateFile(manifestURL: manifestURL, root: root)
        XCTAssertTrue(report.isValid, report.errors.joined(separator: "\n"))
        XCTAssertEqual(manifest.id, "fixture-native")
        XCTAssertEqual(manifest.keyboardEventCount, 2)
        XCTAssertEqual(manifest.trackpadEventCount, 2)

        let loaded = try PackLoader().load(manifest: manifest, root: root, sourceFormat: .tactilemac)
        XCTAssertEqual(loaded.clips["key.down.default"]?.count, 1)
        XCTAssertEqual(loaded.clips["key.up.default"]?.count, 1)
        XCTAssertEqual(loaded.clips["trackpad.click.left"]?.count, 1)
        XCTAssertEqual(loaded.clips["trackpad.scroll.up"]?.count, 1)
        XCTAssertGreaterThan(loaded.clips["key.down.default"]![0].frameCount, 100)
    }

    func testTraversalPathIsRejected() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let root = temp.url.appendingPathComponent("Pack", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let outside = temp.url.appendingPathComponent("outside.wav")
        try Data("x".utf8).write(to: outside)
        XCTAssertThrowsError(try SafePath.resolve(relative: "../outside.wav", in: root)) { error in
            XCTAssertTrue(error.localizedDescription.contains("escapes"))
        }
        XCTAssertThrowsError(try SafePath.resolve(relative: "/tmp/outside.wav", in: root))
        XCTAssertThrowsError(try SafePath.resolve(relative: "sub/../../outside.wav", in: root))
    }

    func testMissingAudioAndBadTimingProduceErrors() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let root = temp.url.appendingPathComponent("Pack", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var manifest = PackManifest(
            id: "bad-pack",
            name: "Bad",
            author: "Tests",
            events: [
                "key.down.default": [PackClip(file: "missing.wav")],
                "key.up.default": [PackClip(file: "other.wav", startMs: 0, durationMs: nil)]
            ]
        )
        let report = PackValidator.validateStructure(manifest: manifest, root: root)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.contains("missing.wav") })
        XCTAssertTrue(report.errors.contains { $0.contains("both startMs and durationMs") })
        XCTAssertThrowsError(try PackLoader().load(manifest: manifest, root: root, sourceFormat: .tactilemac))
        manifest.events = [:]
        XCTAssertFalse(PackValidator.validateStructure(manifest: manifest, root: root).isValid)
    }

    func testUnsupportedEventNameAndBadIDAreReported() {
        let manifest = PackManifest(
            id: "bad id!",
            name: "Bad",
            author: "Tests",
            events: ["key.down.UnknownKey": [PackClip(file: "a.wav")]]
        )
        let report = PackValidator.validateStructure(manifest: manifest, root: URL(fileURLWithPath: "/tmp"))
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.contains("Unsupported event key") })
        XCTAssertTrue(report.errors.contains { $0.contains("Pack id") })
    }

    func testSymlinkEscapeIsRejected() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let root = temp.url.appendingPathComponent("Pack", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let outside = temp.url.appendingPathComponent("outside.wav")
        try Data("x".utf8).write(to: outside)
        let link = root.appendingPathComponent("link.wav")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        XCTAssertThrowsError(try SafePath.resolve(relative: "link.wav", in: root))
    }

    func testOutOfBoundsSegmentIsSkippedWithWarningOrFailsWhenNothingRemains() throws {
        let root = Fixtures.url("Invalid/OutOfBounds")
        let data = try Data(contentsOf: root.appendingPathComponent("config.json"))
        let conversion = try LegacyPackImporter.convert(configData: data, packRoot: root, fallbackID: "out-of-bounds")
        XCTAssertThrowsError(try PackLoader().load(manifest: conversion.manifest, root: root, sourceFormat: .extendedV2))
    }
}
