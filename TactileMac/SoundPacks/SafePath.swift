import Foundation

enum SafePathError: LocalizedError, Equatable {
    case absolute(String)
    case traversal(String)
    case empty
    case notRegularFile(String)
    case symbolicLink(String)
    case unsupportedExtension(String)
    case tooLarge(String, Int64)

    var errorDescription: String? {
        switch self {
        case .absolute(let path): return "Audio path must be relative to the pack folder: \(path)"
        case .traversal(let path): return "Audio path escapes the pack folder: \(path)"
        case .empty: return "An audio path is empty."
        case .notRegularFile(let path): return "Audio file does not exist or is not a regular file: \(path)"
        case .symbolicLink(let path): return "Symbolic links are not allowed inside sound packs: \(path)"
        case .unsupportedExtension(let path): return "Unsupported audio file extension: \(path)"
        case .tooLarge(let path, let limit): return "Audio file is larger than \(limit / 1_000_000) MB: \(path)"
        }
    }
}

enum SafePath {
    static let audioExtensions: Set<String> = ["ogg", "wav", "mp3", "flac"]
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg"]
    static let maximumAudioBytes: Int64 = 200 * 1_000_000

    static func resolve(relative raw: String, in root: URL, allowedExtensions: Set<String>? = audioExtensions, maximumBytes: Int64? = maximumAudioBytes) throws -> URL {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("./") { value.removeFirst(2) }
        guard !value.isEmpty else { throw SafePathError.empty }
        if value.hasPrefix("/") || value.hasPrefix("~") { throw SafePathError.absolute(raw) }
        if value.contains("\0") { throw SafePathError.traversal(raw) }

        let components = value.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !components.isEmpty else { throw SafePathError.empty }
        if components.contains("..") || components.contains(".") { throw SafePathError.traversal(raw) }

        let rootResolved = root.resolvingSymlinksInPath().standardizedFileURL
        var candidate = root
        for component in components { candidate.appendPathComponent(component) }

        var probe = rootResolved
        for component in components {
            probe.appendPathComponent(component)
            let values = try probe.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values.isSymbolicLink == true { throw SafePathError.symbolicLink(raw) }
        }

        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        let prefix = rootResolved.path.hasSuffix("/") ? rootResolved.path : rootResolved.path + "/"
        guard resolved.path.hasPrefix(prefix) else { throw SafePathError.traversal(raw) }

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: resolved.path)
        } catch {
            throw SafePathError.notRegularFile(raw)
        }
        guard (attributes[.type] as? FileAttributeType) == .typeRegular else {
            throw SafePathError.notRegularFile(raw)
        }

        if let allowedExtensions {
            let ext = resolved.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else { throw SafePathError.unsupportedExtension(raw) }
        }

        if let maximumBytes, let size = attributes[.size] as? NSNumber, size.int64Value > maximumBytes {
            throw SafePathError.tooLarge(raw, maximumBytes)
        }
        return resolved
    }
}
