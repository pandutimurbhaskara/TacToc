import Foundation

struct SettingsLoadResult {
    var settings: AppSettings
    var warning: String?
}

final class SettingsStore {
    let fileURL: URL

    init(paths: AppPaths) {
        fileURL = paths.settings
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() -> SettingsLoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return SettingsLoadResult(settings: AppSettings(), warning: nil)
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let settings = try decoder.decode(AppSettings.self, from: data)
            guard settings.schemaVersion <= AppSettings.currentSchemaVersion else {
                throw SettingsError.newerSchema(settings.schemaVersion)
            }
            return SettingsLoadResult(settings: settings, warning: nil)
        } catch {
            let backup = settingsBackupURL()
            try? FileManager.default.copyItem(at: fileURL, to: backup)
            return SettingsLoadResult(
                settings: AppSettings(),
                warning: "Settings could not be read. Defaults were restored; the old file was kept at \(backup.lastPathComponent)."
            )
        }
    }

    func save(_ settings: AppSettings) throws {
        var copy = settings
        copy.schemaVersion = AppSettings.currentSchemaVersion
        copy.clamp()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(copy)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    private func settingsBackupURL() -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return fileURL.deletingLastPathComponent().appendingPathComponent("settings.invalid-\(stamp).json")
    }
}

enum SettingsError: LocalizedError {
    case newerSchema(Int)

    var errorDescription: String? {
        switch self {
        case .newerSchema(let version):
            return "This settings file uses schema \(version), newer than this build supports."
        }
    }
}
