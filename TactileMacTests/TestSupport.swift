import Foundation
import XCTest
@testable import TactileMac

final class FixtureMarker {}

enum Fixtures {
    static var root: URL {
        let bundle = Bundle(for: FixtureMarker.self)
        let candidates = [
            bundle.resourceURL?.appendingPathComponent("Fixtures", isDirectory: true),
            bundle.bundleURL.appendingPathComponent("Contents/Resources/Fixtures", isDirectory: true),
            Bundle.main.resourceURL?.appendingPathComponent("Fixtures", isDirectory: true)
        ].compactMap { $0 }
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        fatalError("Fixtures not found in test bundle. Looked in: \(candidates.map(\.path))")
    }

    static func url(_ name: String) -> URL {
        root.appendingPathComponent(name)
    }

    static func configData(_ name: String) throws -> Data {
        try Data(contentsOf: url(name).appendingPathComponent("config.json"))
    }
}

struct TemporaryDirectory {
    let url: URL

    init(prefix: String = "TactileMacTests") throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

func makePaths(in temp: TemporaryDirectory) throws -> AppPaths {
    let paths = AppPaths(applicationSupport: temp.url.appendingPathComponent("Support", isDirectory: true))
    try paths.prepare()
    return paths
}

func writeJSON(_ value: Any, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}
