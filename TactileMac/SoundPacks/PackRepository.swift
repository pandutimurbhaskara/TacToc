import Foundation

struct PackScanResult {
    var packs: [InstalledPack] = []
    var warnings: [String] = []
}

final class PackRepository {
    private let paths: AppPaths
    private let builtInRoot: URL?
    private let fileManager = FileManager.default

    init(paths: AppPaths, builtInRoot: URL? = nil) {
        self.paths = paths
        self.builtInRoot = builtInRoot ?? Bundle.main.resourceURL?.appendingPathComponent("BuiltInPacks", isDirectory: true)
    }

    func scan() -> PackScanResult {
        var result = PackScanResult()
        var seen = Set<String>()

        if let builtInRoot {
            scanRoot(builtInRoot, builtIn: true, seen: &seen, result: &result)
        } else {
            result.warnings.append("The built-in sound pack folder is missing from the app bundle.")
        }
        do {
            try paths.prepare()
            scanRoot(paths.soundPacks, builtIn: false, seen: &seen, result: &result)
        } catch {
            result.warnings.append("The sound pack folder could not be prepared: \(error.localizedDescription)")
        }

        let builtInOrder = ["thock", "clicky", "linear", "soft"]
        result.packs.sort { lhs, rhs in
            if lhs.isBuiltIn != rhs.isBuiltIn { return lhs.isBuiltIn }
            if lhs.isBuiltIn {
                let l = builtInOrder.firstIndex(of: lhs.id) ?? 99
                let r = builtInOrder.firstIndex(of: rhs.id) ?? 99
                if l != r { return l < r }
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return result
    }

    private func scanRoot(_ root: URL, builtIn: Bool, seen: inout Set<String>, result: inout PackScanResult) {
        guard fileManager.fileExists(atPath: root.path) else {
            if !builtIn { result.warnings.append("The user sound pack folder does not exist yet.") }
            return
        }
        let folders: [URL]
        do {
            folders = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        } catch {
            result.warnings.append("Could not read \(root.lastPathComponent): \(error.localizedDescription)")
            return
        }

        for folder in folders {
            let manifestURL = folder.appendingPathComponent(PackManifest.manifestFileName)
            let configURL = folder.appendingPathComponent("config.json")
            if !fileManager.fileExists(atPath: manifestURL.path) {
                if fileManager.fileExists(atPath: configURL.path) {
                    result.warnings.append("\(folder.lastPathComponent) is a raw legacy folder. Use Import to validate and add it.")
                }
                continue
            }
            do {
                let (manifest, report) = try PackValidator.validateFile(manifestURL: manifestURL, root: folder)
                let provenance = readProvenance(folder: folder)
                var warnings = report.warnings + (provenance?.warnings ?? [])
                var issue: String?
                if !report.errors.isEmpty { issue = report.errors.joined(separator: "\n") }
                var id = manifest.id
                if seen.contains(id) {
                    issue = (issue.map { $0 + "\n" } ?? "") + "Another installed pack already uses the id \"\(id)\"."
                    id = "\(id)#\(folder.lastPathComponent)"
                }
                seen.insert(manifest.id)
                let source = provenance?.sourceFormat ?? .tactilemac
                if provenance == nil && !builtIn {
                    warnings.append("This pack has no import provenance file; it is treated as a native TactileMac pack.")
                }
                let pack = InstalledPack(
                    id: id,
                    manifest: manifest,
                    rootURL: folder,
                    isBuiltIn: builtIn,
                    sourceFormat: source,
                    warnings: Array(Set(warnings)).sorted(),
                    issue: issue
                )
                result.packs.append(pack)
            } catch {
                let placeholder = PackManifest(
                    id: AppPaths.sanitizedID(folder.lastPathComponent, fallback: "invalid-pack"),
                    name: folder.lastPathComponent,
                    author: "Unknown",
                    events: [:]
                )
                result.packs.append(InstalledPack(
                    id: "invalid:\(folder.lastPathComponent)",
                    manifest: placeholder,
                    rootURL: folder,
                    isBuiltIn: builtIn,
                    sourceFormat: .tactilemac,
                    warnings: [],
                    issue: error.localizedDescription
                ))
            }
        }
    }

    private func readProvenance(folder: URL) -> PackProvenance? {
        let url = folder.appendingPathComponent(PackProvenance.fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PackProvenance.self, from: data)
    }
}
