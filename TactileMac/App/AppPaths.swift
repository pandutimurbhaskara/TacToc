import Foundation

struct AppPaths {
    let applicationSupport: URL

    init(applicationSupport: URL? = nil) {
        if let applicationSupport {
            self.applicationSupport = applicationSupport
        } else if let override = ProcessInfo.processInfo.environment["TACTILEMAC_DATA_DIR"], !override.isEmpty {
            self.applicationSupport = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
            self.applicationSupport = base.appendingPathComponent("TactileMac", isDirectory: true)
        }
    }

    var soundPacks: URL { applicationSupport.appendingPathComponent("SoundPacks", isDirectory: true) }
    var imports: URL { applicationSupport.appendingPathComponent("Imports", isDirectory: true) }
    var settings: URL { applicationSupport.appendingPathComponent("settings.json") }

    func prepare() throws {
        try FileManager.default.createDirectory(at: applicationSupport, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: soundPacks, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var support = applicationSupport
        try? support.setResourceValues(values)
    }

    static func sanitizedID(_ raw: String, fallback: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        let scalars = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        var value = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        while value.contains("--") { value = value.replacingOccurrences(of: "--", with: "-") }
        if value.isEmpty || value.count > 80 { value = fallback }
        if value == "." || value == ".." { value = fallback }
        return value
    }
}
