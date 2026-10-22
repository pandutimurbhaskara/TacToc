import Foundation

enum PackImportError: LocalizedError {
    case unsupportedSource(String)
    case unreadable(String)
    case unsafe(String)
    case tooLarge(String)
    case alreadyInstalled(String)
    case noPackFound
    case multiplePacksFound
    case validation([String])
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSource(let message): return message
        case .unreadable(let message): return "The pack could not be read: \(message)"
        case .unsafe(let message): return "The pack was rejected for safety reasons: \(message)"
        case .tooLarge(let message): return "The pack is too large: \(message)"
        case .alreadyInstalled(let id): return "A pack with the id \"\(id)\" is already installed. Remove it first, then import again."
        case .noPackFound: return "No config.json or tactilemac.pack.json was found in the selected item."
        case .multiplePacksFound: return "More than one sound pack configuration was found. Import one pack at a time."
        case .validation(let messages): return messages.joined(separator: "\n")
        case .copyFailed(let message): return "The pack could not be installed: \(message)"
        }
    }
}

final class PackImportService {
    private let paths: AppPaths
    private let fileManager = FileManager.default
    private let maximumFiles = 2000
    private let maximumBytes: Int64 = 500 * 1_000_000
    private let maximumCompressedBytes: Int64 = 500 * 1_000_000

    init(paths: AppPaths) {
        self.paths = paths
    }

    func importPack(from sourceURL: URL, reservedIDs: Set<String> = []) throws -> ImportOutcome {
        try paths.prepare()
        let workspace = paths.imports.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workspace) }

        let stagedRoot = workspace.appendingPathComponent("source", isDirectory: true)
        try stage(sourceURL, into: stagedRoot)
        let packRoot = try locatePackRoot(in: stagedRoot)

        let manifestURL = packRoot.appendingPathComponent(PackManifest.manifestFileName)
        let configURL = packRoot.appendingPathComponent("config.json")

        let manifest: PackManifest
        let sourceFormat: PackSourceFormat
        let detectedVersion: String?
        let sourceConfig: String
        var warnings: [String] = []

        if fileManager.fileExists(atPath: manifestURL.path) {
            let data: Data
            do { data = try Data(contentsOf: manifestURL) }
            catch { throw PackImportError.unreadable(error.localizedDescription) }
            do {
                manifest = try PackValidator.decodeManifest(data: data)
            } catch {
                throw PackImportError.validation([error.localizedDescription])
            }
            let report = PackValidator.validateStructure(manifest: manifest, root: packRoot)
            guard report.isValid else { throw PackImportError.validation(report.errors) }
            warnings.append(contentsOf: report.warnings)
            sourceFormat = .tactilemac
            detectedVersion = "schema \(manifest.schemaVersion)"
            sourceConfig = PackManifest.manifestFileName
        } else if fileManager.fileExists(atPath: configURL.path) {
            let data: Data
            do { data = try Data(contentsOf: configURL) }
            catch { throw PackImportError.unreadable(error.localizedDescription) }
            let conversion = try LegacyPackImporter.convert(
                configData: data,
                packRoot: packRoot,
                fallbackID: AppPaths.sanitizedID(packRoot.lastPathComponent, fallback: "imported-pack")
            )
            manifest = conversion.manifest
            sourceFormat = conversion.sourceFormat
            detectedVersion = conversion.detectedVersion
            sourceConfig = "config.json"
            warnings.append(contentsOf: conversion.warnings)
            let report = PackValidator.validateStructure(manifest: manifest, root: packRoot)
            guard report.isValid else { throw PackImportError.validation(report.errors) }
            warnings.append(contentsOf: report.warnings)
        } else {
            throw PackImportError.noPackFound
        }

        if reservedIDs.contains(manifest.id) || fileManager.fileExists(atPath: paths.soundPacks.appendingPathComponent(manifest.id).path) {
            throw PackImportError.alreadyInstalled(manifest.id)
        }

        // Prove every referenced file decodes and every segment has playable
        // frames before anything is installed.
        let loader = PackLoader()
        let loaded: LoadedPack
        do {
            loaded = try loader.load(manifest: manifest, root: packRoot, sourceFormat: sourceFormat)
        } catch {
            throw PackImportError.validation([error.localizedDescription] + warnings)
        }
        warnings.append(contentsOf: loaded.warnings)

        let destination = paths.soundPacks.appendingPathComponent(manifest.id, isDirectory: true)
        let temporaryDestination = paths.soundPacks.appendingPathComponent(".incoming-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: temporaryDestination, withIntermediateDirectories: true)
            try copyContents(of: packRoot, to: temporaryDestination)
            if sourceFormat != .tactilemac {
                try writeManifest(manifest, to: temporaryDestination)
                let provenance = PackProvenance(
                    sourceFormat: sourceFormat,
                    sourceConfig: sourceConfig,
                    converterVersion: PackProvenance.converterVersion,
                    importedAt: Date(),
                    warnings: Array(Set(warnings)).sorted(),
                    detectedVersion: detectedVersion
                )
                try write(provenance, to: temporaryDestination.appendingPathComponent(PackProvenance.fileName))
            }
            try fileManager.moveItem(at: temporaryDestination, to: destination)
        } catch {
            try? fileManager.removeItem(at: temporaryDestination)
            throw PackImportError.copyFailed(error.localizedDescription)
        }

        let pack = InstalledPack(
            id: manifest.id,
            manifest: manifest,
            rootURL: destination,
            isBuiltIn: false,
            sourceFormat: sourceFormat,
            warnings: Array(Set(warnings)).sorted(),
            issue: nil
        )
        return ImportOutcome(
            pack: pack,
            warnings: Array(Set(warnings)).sorted(),
            sourceFormat: sourceFormat,
            sourceDescription: "\(sourceFormat.title) · \(detectedVersion ?? "schema 1")"
        )
    }

    // MARK: - Staging

    private func stage(_ sourceURL: URL, into root: URL) throws {
        let values = try sourceURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
        if values.isDirectory == true {
            try validateTree(sourceURL)
            try copyContents(of: sourceURL, to: root)
            try validateTree(root)
            return
        }
        if values.isRegularFile == true, sourceURL.lastPathComponent == "config.json" || sourceURL.lastPathComponent == PackManifest.manifestFileName {
            try validateTree(sourceURL.deletingLastPathComponent())
            try copyContents(of: sourceURL.deletingLastPathComponent(), to: root)
            try validateTree(root)
            return
        }
        guard sourceURL.pathExtension.lowercased() == "zip" else {
            throw PackImportError.unsupportedSource("Choose a sound-pack folder, a .zip archive, or a pack configuration file.")
        }
        if let size = values.fileSize, Int64(size) > maximumCompressedBytes {
            throw PackImportError.tooLarge("the archive is larger than \(maximumCompressedBytes / 1_000_000) MB")
        }
        try extractZip(sourceURL, to: root)
        try validateTree(root)
    }

    private func extractZip(_ zipURL: URL, to destination: URL) throws {
        let listing = try run("/usr/bin/unzip", ["-Z1", zipURL.path])
        guard listing.status == 0 else {
            throw PackImportError.unreadable(listing.output.isEmpty ? "zlib archive could not be listed" : listing.output)
        }
        let names = listing.output.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard names.count <= maximumFiles else {
            throw PackImportError.tooLarge("the archive contains more than \(maximumFiles) files")
        }
        for name in names {
            if name.hasPrefix("/") || name.contains("..") || name.contains("\0") {
                throw PackImportError.unsafe("archive entry has an unsafe path: \(name)")
            }
        }

        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let extraction = try run("/usr/bin/ditto", ["-x", "-k", zipURL.path, destination.path])
        guard extraction.status == 0 else {
            throw PackImportError.unreadable(extraction.output.isEmpty ? "archive extraction failed" : extraction.output)
        }
    }

    private func locatePackRoot(in staged: URL) throws -> URL {
        let directManifest = staged.appendingPathComponent(PackManifest.manifestFileName)
        let directConfig = staged.appendingPathComponent("config.json")
        if fileManager.fileExists(atPath: directManifest.path) || fileManager.fileExists(atPath: directConfig.path) {
            return staged
        }
        var candidates: [URL] = []
        if let enumerator = fileManager.enumerator(at: staged, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: []) {
            var depth = 0
            for case let url as URL in enumerator {
                depth += 1
                if depth > 2000 { break }
                let name = url.lastPathComponent
                if name == PackManifest.manifestFileName || name == "config.json" {
                    candidates.append(url.deletingLastPathComponent())
                }
            }
        }
        let unique = Array(Set(candidates))
        if unique.isEmpty { throw PackImportError.noPackFound }
        if unique.count > 1 { throw PackImportError.multiplePacksFound }
        return unique[0]
    }

    // MARK: - Files

    private func copyContents(of source: URL, to destination: URL) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let entries = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey], options: [])
        for entry in entries {
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true {
                throw PackImportError.unsafe("symbolic links are not allowed: \(entry.lastPathComponent)")
            }
            if values.isDirectory == true || values.isRegularFile == true {
                try fileManager.copyItem(at: entry, to: destination.appendingPathComponent(entry.lastPathComponent))
            }
        }
    }

    private func validateTree(_ root: URL) throws {
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey], options: []) else {
            throw PackImportError.unreadable("the folder could not be enumerated")
        }
        var count = 0
        var total: Int64 = 0
        for case let url as URL in enumerator {
            count += 1
            if count > maximumFiles { throw PackImportError.tooLarge("more than \(maximumFiles) files") }
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            if values.isSymbolicLink == true {
                throw PackImportError.unsafe("symbolic links are not allowed: \(url.lastPathComponent)")
            }
            if values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
                if total > maximumBytes { throw PackImportError.tooLarge("more than \(maximumBytes / 1_000_000) MB of files") }
            } else if values.isDirectory != true {
                throw PackImportError.unsafe("unsupported file type: \(url.lastPathComponent)")
            }
        }
    }

    private func writeManifest(_ manifest: PackManifest, to root: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: root.appendingPathComponent(PackManifest.manifestFileName), options: .atomic)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Process

    private func run(_ executable: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        do { try process.run() } catch { throw PackImportError.unreadable(error.localizedDescription) }
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: output, encoding: .utf8) ?? ""
        let errorText = String(data: error, encoding: .utf8) ?? ""
        return (process.terminationStatus, text.isEmpty ? errorText : text)
    }
}
