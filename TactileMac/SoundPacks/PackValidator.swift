import Foundation

struct PackValidationReport {
    var errors: [String] = []
    var warnings: [String] = []

    var isValid: Bool { errors.isEmpty }
}

enum PackValidationError: LocalizedError {
    case invalid([String])

    var errorDescription: String? {
        switch self {
        case .invalid(let errors):
            return errors.joined(separator: "\n")
        }
    }
}

enum PackValidator {
    static func decodeManifest(data: Data) throws -> PackManifest {
        do {
            return try JSONDecoder().decode(PackManifest.self, from: data)
        } catch {
            throw PackValidationError.invalid(["The JSON could not be decoded as a TactileMac pack: \(error.localizedDescription)"])
        }
    }

    static func validateStructure(manifest: PackManifest, root: URL) -> PackValidationReport {
        var report = PackValidationReport()

        if manifest.schema != PackManifest.schemaName {
            report.errors.append("Expected schema \"\(PackManifest.schemaName)\", found \"\(manifest.schema)\".")
        }
        if manifest.schemaVersion > PackManifest.schemaVersion {
            report.errors.append("This pack uses schema \(manifest.schemaVersion); this version of TactileMac supports schema \(PackManifest.schemaVersion).")
        } else if manifest.schemaVersion < 1 {
            report.errors.append("Invalid schema version \(manifest.schemaVersion).")
        }
        let safeID = AppPaths.sanitizedID(manifest.id, fallback: "")
        if manifest.id.isEmpty || safeID != manifest.id {
            report.errors.append("Pack id must contain only letters, numbers, dots, hyphens and underscores (maximum 80 characters).")
        }
        if manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            report.errors.append("Pack name is required.")
        }
        if manifest.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            report.errors.append("Pack author is required.")
        }
        if manifest.events.isEmpty {
            report.errors.append("The pack has no event definitions.")
        }
        if manifest.events.count > 2000 {
            report.errors.append("The pack has more than 2000 event definitions.")
        }
        if let volume = manifest.recommendedVolume, !(0...2).contains(volume) {
            report.errors.append("recommendedVolume must be between 0 and 2.")
        }
        if let variation = manifest.pitchVariation, !(0...2).contains(variation) {
            report.errors.append("pitchVariation must be between 0 and 2 semitones.")
        }

        var allFiles = Set<String>()
        var totalClips = 0
        for (event, clips) in manifest.events.sorted(by: { $0.key < $1.key }) {
            if !PackEvent.isSupported(event) {
                report.errors.append("Unsupported event key \"\(event)\".")
            }
            if clips.isEmpty {
                report.warnings.append("Event \"\(event)\" has no clips and will be ignored.")
            }
            if clips.count > 32 {
                report.errors.append("Event \"\(event)\" has more than 32 variations.")
            }
            for (index, clip) in clips.enumerated() {
                totalClips += 1
                if clip.file.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    report.errors.append("\(event)[\(index)] has an empty audio path.")
                    continue
                }
                do {
                    _ = try SafePath.resolve(relative: clip.file, in: root)
                    allFiles.insert(clip.file)
                } catch {
                    report.errors.append("\(event)[\(index)]: \(error.localizedDescription)")
                }
                if (clip.startMs == nil) != (clip.durationMs == nil) {
                    report.errors.append("\(event)[\(index)] must specify both startMs and durationMs, or neither.")
                }
                if let start = clip.startMs, start < 0 {
                    report.errors.append("\(event)[\(index)] has a negative startMs.")
                }
                if let duration = clip.durationMs, duration <= 0 {
                    report.errors.append("\(event)[\(index)] has a non-positive durationMs.")
                }
                if let duration = clip.durationMs, duration > 600_000 {
                    report.errors.append("\(event)[\(index)] is longer than 600 seconds.")
                }
                if let gain = clip.gain, !(0...4).contains(gain) {
                    report.errors.append("\(event)[\(index)] gain must be between 0 and 4.")
                }
                if let pitch = clip.pitchSemitones, abs(pitch) > 12 {
                    report.errors.append("\(event)[\(index)] pitch must be within ±12 semitones.")
                }
            }
        }
        if totalClips > 5000 {
            report.errors.append("The pack has more than 5000 sound variations.")
        }
        if allFiles.count > 200 {
            report.errors.append("The pack references more than 200 audio files.")
        }

        if let icon = manifest.icon, !icon.isEmpty {
            do {
                _ = try SafePath.resolve(relative: icon, in: root, allowedExtensions: SafePath.imageExtensions, maximumBytes: 2_000_000)
            } catch {
                report.warnings.append("Pack icon is unavailable: \(error.localizedDescription)")
            }
        }
        return report
    }

    static func validateFile(manifestURL: URL, root: URL) throws -> (PackManifest, PackValidationReport) {
        let data = try Data(contentsOf: manifestURL)
        let manifest = try decodeManifest(data: data)
        let report = validateStructure(manifest: manifest, root: root)
        return (manifest, report)
    }
}

struct LoadedPack {
    let manifest: PackManifest
    let rootURL: URL
    let sourceFormat: PackSourceFormat
    let clips: [String: [ResolvedClip]]
    let warnings: [String]
}

enum PackLoaderError: LocalizedError {
    case noUsableClips([String])

    var errorDescription: String? {
        switch self {
        case .noUsableClips(let warnings):
            return "The pack contains no usable sounds.\n" + warnings.joined(separator: "\n")
        }
    }
}

final class PackLoader {
    private let cache = AudioDecodeCache()

    func load(manifest: PackManifest, root: URL, sourceFormat: PackSourceFormat) throws -> LoadedPack {
        var warnings: [String] = []
        var resolved: [String: [ResolvedClip]] = [:]

        for (event, clips) in manifest.events {
            var eventClips: [ResolvedClip] = []
            for (index, clip) in clips.enumerated() {
                do {
                    let url = try SafePath.resolve(relative: clip.file, in: root)
                    let audio = try cache.decode(url)
                    let startSeconds = (clip.startMs ?? 0) / 1000
                    let requestedDuration = (clip.durationMs ?? audio.duration * 1000) / 1000
                    let startFrame = max(0, Int((startSeconds * audio.sampleRate).rounded()))
                    var endFrame = startFrame + max(1, Int((requestedDuration * audio.sampleRate).rounded()))
                    if startFrame >= audio.frameCount {
                        warnings.append("\(event)[\(index)] starts after the end of \(clip.file); the clip was skipped.")
                        continue
                    }
                    if endFrame > audio.frameCount {
                        endFrame = audio.frameCount
                        if requestedDuration > 0 {
                            warnings.append("\(event)[\(index)] extends past the end of \(clip.file); the clip was shortened.")
                        }
                    }
                    let frameCount = endFrame - startFrame
                    guard frameCount > 0 else {
                        warnings.append("\(event)[\(index)] has no playable frames and was skipped.")
                        continue
                    }
                    eventClips.append(ResolvedClip(
                        sample: audio,
                        startFrame: startFrame,
                        frameCount: frameCount,
                        gain: Float(clip.gain ?? 1),
                        pitchSemitones: clip.pitchSemitones ?? 0
                    ))
                } catch {
                    warnings.append("\(event)[\(index)]: \(error.localizedDescription)")
                }
            }
            if eventClips.isEmpty {
                if !clips.isEmpty { warnings.append("Event \"\(event)\" has no playable clips and was removed.") }
            } else {
                resolved[event] = eventClips
            }
        }

        guard !resolved.isEmpty else { throw PackLoaderError.noUsableClips(warnings) }
        return LoadedPack(manifest: manifest, rootURL: root, sourceFormat: sourceFormat, clips: resolved, warnings: warnings)
    }
}
