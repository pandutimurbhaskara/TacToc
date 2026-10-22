import Foundation

enum LegacyPackFormat {
    case legacyV1
    case legacyV2
    case extendedV2
}

struct LegacyPackConversion {
    let manifest: PackManifest
    let sourceFormat: PackSourceFormat
    let detectedVersion: String
    let warnings: [String]
}

enum LegacyPackImportError: LocalizedError {
    case notLegacyPack
    case unsupportedVersion(String)
    case malformed(String)
    case noUsableDefinitions([String])
    case noAudioFile

    var errorDescription: String? {
        switch self {
        case .notLegacyPack:
            return "This folder does not contain a recognized legacy config.json (missing defines/definitions)."
        case .unsupportedVersion(let message):
            return message
        case .malformed(let message):
            return "The sound pack configuration is malformed: \(message)"
        case .noUsableDefinitions(let warnings):
            let detail = warnings.isEmpty ? "" : "\n\n" + warnings.joined(separator: "\n")
            return "No supported key or mouse definitions were found." + detail
        case .noAudioFile:
            return "The pack does not reference a readable audio file."
        }
    }
}

enum LegacyPackImporter {
    private static let warningLimit = 80

    static func looksLikeLegacyPack(_ object: [String: Any]) -> Bool {
        object["defines"] != nil || object["definitions"] != nil
    }

    static func detect(_ object: [String: Any]) -> LegacyPackFormat? {
        if object["definitions"] != nil {
            return .extendedV2
        }
        if object["defines"] != nil {
            let version = (object["version"] as? NSNumber)?.intValue ?? Int(object["version"] as? String ?? "") ?? 1
            let hasUp = object["soundup"] != nil || (object["defines"] as? [String: Any])?.keys.contains(where: { $0.hasSuffix("-up") }) == true
            return (version >= 2 || hasUp) ? .legacyV2 : .legacyV1
        }
        return nil
    }

    static func convert(configData: Data, packRoot: URL, fallbackID: String) throws -> LegacyPackConversion {
        let any: Any
        do {
            any = try JSONSerialization.jsonObject(with: configData)
        } catch {
            throw LegacyPackImportError.malformed("invalid JSON (\(error.localizedDescription))")
        }
        guard let object = any as? [String: Any] else {
            throw LegacyPackImportError.malformed("the top-level JSON value must be an object")
        }
        guard let format = detect(object) else { throw LegacyPackImportError.notLegacyPack }

        switch format {
        case .legacyV1, .legacyV2:
            return try convertLegacy(object, format: format, packRoot: packRoot, fallbackID: fallbackID)
        case .extendedV2:
            return try convertExtendedV2(object, packRoot: packRoot, fallbackID: fallbackID)
        }
    }

    // MARK: - Extended V2

    private static func convertExtendedV2(_ object: [String: Any], packRoot: URL, fallbackID: String) throws -> LegacyPackConversion {
        var warnings: [String] = []
        let rawVersion = object["config_version"]
        var detectedVersion = "2"
        if let rawVersion {
            let version: Int?
            if let number = rawVersion as? NSNumber { version = number.intValue }
            else if let string = rawVersion as? String { version = Int(string.trimmingCharacters(in: .whitespaces)) }
            else { version = nil }
            guard let version else {
                throw LegacyPackImportError.malformed("config_version must be a number or numeric string")
            }
            if version > 2 {
                throw LegacyPackImportError.unsupportedVersion("This pack declares config_version \(version); it requires a newer extended V2 format than TactileMac understands.")
            }
            if version < 2 {
                throw LegacyPackImportError.malformed("config_version \(version) does not use the Extended V2 structure")
            }
            detectedVersion = String(version)
        }

        guard let definitions = (object["definitions"] ?? object["defs"]) as? [String: Any], !definitions.isEmpty else {
            throw LegacyPackImportError.malformed("definitions must be a non-empty object")
        }
        let method = (object["definition_method"] as? String)?.lowercased() ?? "single"
        guard method == "single" || method == "multi" else {
            throw LegacyPackImportError.malformed("definition_method must be \"single\" or \"multi\"")
        }

        let mainAudio = (object["audio_file"] as? String).flatMap { nonEmpty($0) }
        if method == "single" && mainAudio == nil {
            let hasPerKeyAudio = definitions.values.contains { value in
                guard let object = value as? [String: Any] else { return false }
                return nonEmpty(object["audio_file"] as? String) != nil
            }
            if !hasPerKeyAudio { throw LegacyPackImportError.noAudioFile }
        }

        let name = nonEmpty(object["name"] as? String) ?? packRoot.lastPathComponent
        if nonEmpty(object["name"] as? String) == nil { warnings.append("The pack has no name; the folder name was used.") }
        let author = nonEmpty(object["author"] as? String) ?? nonEmpty(object["m_author"] as? String) ?? "Unknown"
        if nonEmpty(object["author"] as? String) == nil && nonEmpty(object["m_author"] as? String) == nil {
            warnings.append("The pack has no author; \"Unknown\" was recorded.")
        }

        var events: [String: [PackClip]] = [:]
        var unsupported: [String] = []

        for (rawKey, value) in definitions.sorted(by: { $0.key < $1.key }) {
            let definition: [String: Any]
            let directTiming: Any?
            if let object = value as? [String: Any] {
                definition = object
                directTiming = object["timing"]
            } else if value is [Any] {
                definition = [:]
                directTiming = value
            } else {
                warnings.append("Definition \"\(rawKey)\" is not an object or timing array and was skipped.")
                continue
            }
            let audioName = nonEmpty(definition["audio_file"] as? String) ?? mainAudio
            guard let audioName else {
                warnings.append("Definition \"\(rawKey)\" has no audio_file and the pack has no main audio file.")
                continue
            }
            if !audioExists(audioName, in: packRoot) {
                warnings.append("Definition \"\(rawKey)\" references a missing audio file: \(audioName)")
                continue
            }

            let timings: [[Double]]
            if let timingValue = directTiming {
                guard let parsed = parseTimingPairs(timingValue) else {
                    warnings.append("Definition \"\(rawKey)\" has an invalid timing array and was skipped.")
                    continue
                }
                timings = parsed
            } else {
                timings = []
            }

            let clips = timings.map { pair -> PackClip in
                // Extended V2 timing pairs are [start, end] milliseconds.
                PackClip(file: audioName, startMs: pair[0], durationMs: max(0.001, pair[1] - pair[0]))
            }
            let finalClips = clips.isEmpty ? [PackClip(file: audioName)] : clips

            let eventKeys = eventKeysForExtendedV2Name(rawKey)
            if eventKeys.isEmpty {
                unsupported.append(rawKey)
                continue
            }
            for event in eventKeys {
                events[event, default: []].append(contentsOf: finalClips)
            }
        }

        if !unsupported.isEmpty {
            warnings.append("Unsupported key or button names were skipped: \(summarize(unsupported)).")
        }
        guard !events.isEmpty else { throw LegacyPackImportError.noUsableDefinitions(capped(warnings)) }

        let options = object["options"] as? [String: Any]
        let recommendedVolume = (options?["recommended_volume"] as? NSNumber)?.doubleValue
        let randomPitch = (options?["random_pitch"] as? NSNumber)?.boolValue ?? false
        let id = AppPaths.sanitizedID(nonEmpty(object["id"] as? String) ?? fallbackID, fallback: fallbackID)
        let license = nonEmpty(object["license"] as? String)

        let manifest = PackManifest(
            id: id,
            name: name,
            author: author,
            description: nonEmpty(object["description"] as? String),
            license: license,
            icon: nonEmpty(object["icon"] as? String),
            recommendedVolume: recommendedVolume,
            pitchVariation: randomPitch ? 0.2 : nil,
            events: events
        )
        return LegacyPackConversion(
            manifest: manifest,
            sourceFormat: .extendedV2,
            detectedVersion: "config_version \(detectedVersion), \(method)",
            warnings: capped(warnings)
        )
    }

    private static func eventKeysForExtendedV2Name(_ raw: String) -> [String] {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "MouseLeft": return ["trackpad.click.left"]
        case "MouseRight": return ["trackpad.click.right"]
        case "MouseMiddle": return ["trackpad.click.middle"]
        case "WheelUp": return ["trackpad.scroll.up"]
        case "WheelDown": return ["trackpad.scroll.down"]
        default:
            if name.hasPrefix("Button") { return [] }
            guard let descriptor = KeyCodeMap.descriptor(named: name) else { return [] }
            return ["key.down.\(descriptor.w3cName)"]
        }
    }

    private static func parseTimingPairs(_ value: Any) -> [[Double]]? {
        guard let array = value as? [Any] else { return nil }
        var pairs: [[Double]] = []
        for item in array {
            guard let pair = item as? [Any], pair.count == 2,
                  let start = (pair[0] as? NSNumber)?.doubleValue,
                  let end = (pair[1] as? NSNumber)?.doubleValue else { return nil }
            guard start >= 0, end > start else { return nil }
            pairs.append([start, end])
        }
        return pairs
    }

    // MARK: - Legacy V1 / Legacy V2

    private static func convertLegacy(_ object: [String: Any], format: LegacyPackFormat, packRoot: URL, fallbackID: String) throws -> LegacyPackConversion {
        var warnings: [String] = []
        let isLegacyV2 = format == .legacyV2
        let method = ((object["key_define_type"] as? String) ?? "single").lowercased()
        guard method == "single" || method == "multi" else {
            throw LegacyPackImportError.malformed("key_define_type must be \"single\" or \"multi\"")
        }
        guard let defines = object["defines"] as? [String: Any], !defines.isEmpty else {
            throw LegacyPackImportError.malformed("defines must be a non-empty object")
        }

        let mainSound = nonEmpty(object["sound"] as? String)
        let mainUp = nonEmpty(object["soundup"] as? String)
        let isMousePack = looksLikeMousePack(object, root: packRoot, defines: defines)

        let name = nonEmpty(object["name"] as? String) ?? packRoot.lastPathComponent
        if nonEmpty(object["name"] as? String) == nil { warnings.append("The pack has no name; the folder name was used.") }
        let author = nonEmpty(object["author"] as? String) ?? "Unknown"
        if nonEmpty(object["author"] as? String) == nil { warnings.append("The pack has no author; \"Unknown\" was recorded.") }

        var events: [String: [PackClip]] = [:]
        var unsupportedCodes: [String] = []

        if isMousePack {
            for (rawCode, value) in defines.sorted(by: { $0.key < $1.key }) {
                guard let (button, isRelease) = LegacyKeyMap.mouseButton(forLegacyCode: rawCode) else {
                    unsupportedCodes.append(rawCode)
                    continue
                }
                if isRelease {
                    warnings.append("Mouse release definition \"\(rawCode)\" was skipped: TactileMac plays one sound per button press.")
                    continue
                }
                let event = "trackpad.click.\(button.rawValue)"
                let clips = try legacyClips(value: value, method: method, fallbackFile: mainSound, root: packRoot, label: rawCode, warnings: &warnings)
                if !clips.isEmpty { events[event, default: []].append(contentsOf: clips) }
            }
        } else {
            // Collect exact definitions first.
            var downByName: [String: [PackClip]] = [:]
            var upByName: [String: [PackClip]] = [:]
            for (rawCode, value) in defines.sorted(by: { $0.key < $1.key }) {
                let isUp = rawCode.hasSuffix("-up")
                let baseCode = isUp ? String(rawCode.dropLast(3)) : rawCode
                if isUp && !isLegacyV2 { continue }
                guard let name = LegacyKeyMap.w3cName(forLegacyCode: baseCode),
                      let descriptor = KeyCodeMap.descriptor(named: name) else {
                    if !(value is NSNull) { unsupportedCodes.append(rawCode) }
                    continue
                }
                let fallback = (method == "single") ? mainSound : (isUp ? mainUp : mainSound)
                let clips = try legacyClips(value: value, method: method, fallbackFile: fallback, root: packRoot, label: rawCode, warnings: &warnings)
                if clips.isEmpty { continue }
                if isUp { upByName[descriptor.w3cName, default: []].append(contentsOf: clips) }
                else { downByName[descriptor.w3cName, default: []].append(contentsOf: clips) }
            }

            if isLegacyV2 && method == "multi" {
                // Legacy V2 expands every standard key to the sound/soundup
                // fallback. Mirroring that is what makes a sparse V2 pack
                // complete instead of silent on most keys.
                let fallbackDown = mainSound.map { fileClips($0, root: packRoot, label: "sound", warnings: &warnings) } ?? []
                let fallbackUp = mainUp.map { fileClips($0, root: packRoot, label: "soundup", warnings: &warnings) } ?? []
                for name in KeyCodeMap.knownNames {
                    if let clips = downByName[name] {
                        events["key.down.\(name)"] = clips
                    } else if !fallbackDown.isEmpty {
                        events["key.down.\(name)"] = fallbackDown
                    }
                    if let clips = upByName[name] {
                        events["key.up.\(name)"] = clips
                    } else if !fallbackUp.isEmpty {
                        events["key.up.\(name)"] = fallbackUp
                    }
                }
            } else {
                for (name, clips) in downByName { events["key.down.\(name)"] = clips }
                if isLegacyV2 {
                    for (name, clips) in upByName { events["key.up.\(name)"] = clips }
                } else if !upByName.isEmpty {
                    warnings.append("Key-up definitions were found in a V1 pack and were skipped.")
                }
            }

            if isLegacyV2 && method == "single" && mainUp != nil {
                warnings.append("soundup is not used by single-file packs, matching the legacy behaviour.")
            }
        }

        if !unsupportedCodes.isEmpty {
            warnings.append("Unsupported key codes were skipped: \(summarize(unsupportedCodes)).")
        }
        guard !events.isEmpty else { throw LegacyPackImportError.noUsableDefinitions(capped(warnings)) }

        let id = AppPaths.sanitizedID(nonEmpty(object["id"] as? String) ?? fallbackID, fallback: fallbackID)
        let sourceFormat: PackSourceFormat = isLegacyV2 ? .legacyV2 : .legacyV1
        let manifest = PackManifest(
            id: id,
            name: name,
            author: author,
            description: nonEmpty(object["description"] as? String),
            license: nonEmpty(object["license"] as? String),
            icon: nonEmpty(object["icon"] as? String),
            recommendedVolume: nil,
            pitchVariation: nil,
            events: events
        )
        let version = format == .legacyV1 ? "1" : "2"
        return LegacyPackConversion(
            manifest: manifest,
            sourceFormat: sourceFormat,
            detectedVersion: "legacy version \(version), \(method)",
            warnings: capped(warnings)
        )
    }

    private static func looksLikeMousePack(_ object: [String: Any], root: URL, defines: [String: Any]) -> Bool {
        if let type = (object["soundpack_type"] as? String)?.lowercased(), type.contains("mouse") { return true }
        if root.lastPathComponent.lowercased().contains("mouse") { return true }
        let numericKeys = defines.keys.filter { LegacyKeyMap.isNumericCode($0) }
        guard !numericKeys.isEmpty else { return false }
        let lowercasedPaths = defines.values.compactMap { $0 as? String }.map { $0.lowercased() }
        let hasMouseWords = lowercasedPaths.contains { path in
            ["left", "right", "mouse", "scroll", "click"].contains { path.contains($0) }
        }
        return hasMouseWords && numericKeys.allSatisfy { key in
            let trimmed = key.trimmingCharacters(in: .whitespaces)
            let numeric = Int(trimmed) ?? -1
            return (1...3).contains(numeric)
        }
    }

    private static func legacyClips(value: Any, method: String, fallbackFile: String?, root: URL, label: String, warnings: inout [String]) throws -> [PackClip] {
        if value is NSNull { return [] }
        if method == "multi" {
            guard let file = value as? String else {
                warnings.append("Definition \"\(label)\" is not a file path and was skipped.")
                return []
            }
            return fileClips(file, root: root, label: label, warnings: &warnings)
        }
        guard let array = value as? [Any] else {
            warnings.append("Definition \"\(label)\" is not a [start, duration] pair and was skipped.")
            return []
        }
        guard array.count >= 2,
              let start = (array[0] as? NSNumber)?.doubleValue,
              let duration = (array[1] as? NSNumber)?.doubleValue,
              start >= 0, duration > 0 else {
            warnings.append("Definition \"\(label)\" has invalid timing and was skipped.")
            return []
        }
        guard let file = fallbackFile else {
            warnings.append("Definition \"\(label)\" has timing but the pack has no main sound file.")
            return []
        }
        guard audioExists(file, in: root) else {
            warnings.append("Definition \"\(label)\" references a missing audio file: \(file)")
            return []
        }
        return [PackClip(file: normalizedRelative(file), startMs: start, durationMs: duration)]
    }

    private static func fileClips(_ file: String, root: URL, label: String, warnings: inout [String]) -> [PackClip] {
        let expanded = expandedLegacyFiles(file, root: root)
        if expanded.isEmpty {
            warnings.append("Definition \"\(label)\" references a missing audio file: \(file)")
            return []
        }
        return expanded.map { PackClip(file: $0) }
    }

    /// Legacy V2 accepts a `{start-end}` range in a filename and chose one
    /// number at pack load. TactileMac expands every existing member as a
    /// playback variation, which preserves the intended variation without
    /// hard-coding the legacy random pick.
    private static func expandedLegacyFiles(_ raw: String, root: URL) -> [String] {
        let file = normalizedRelative(raw)
        guard let open = file.firstIndex(of: "{"),
              let close = file[open...].firstIndex(of: "}") else {
            return audioExists(file, in: root) ? [file] : []
        }
        let rangeText = String(file[file.index(after: open)..<close])
        let parts = rangeText.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let lower = Int(parts[0]), let upper = Int(parts[1]),
              upper >= lower, upper - lower <= 99 else {
            return audioExists(file, in: root) ? [file] : []
        }
        var results: [String] = []
        for number in lower...upper {
            let candidate = String(file[..<open]) + String(number) + String(file[file.index(after: close)...])
            if audioExists(candidate, in: root) { results.append(candidate) }
        }
        return results
    }

    private static func audioExists(_ path: String, in root: URL) -> Bool {
        (try? SafePath.resolve(relative: path, in: root)) != nil
    }

    private static func normalizedRelative(_ path: String) -> String {
        var value = path
        while value.hasPrefix("./") { value.removeFirst(2) }
        return value
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func summarize(_ values: [String]) -> String {
        let unique = Array(Set(values)).sorted()
        if unique.count <= 24 { return unique.joined(separator: ", ") }
        return unique.prefix(24).joined(separator: ", ") + ", and \(unique.count - 24) more"
    }

    private static func capped(_ warnings: [String]) -> [String] {
        if warnings.count <= warningLimit { return warnings }
        return Array(warnings.prefix(warningLimit)) + ["…and \(warnings.count - warningLimit) more warnings."]
    }
}
