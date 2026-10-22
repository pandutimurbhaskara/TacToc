import Foundation

struct PackManifest: Codable, Equatable {
    static let schemaName = "tactilemac.pack"
    static let schemaVersion = 1
    static let manifestFileName = "tactilemac.pack.json"

    var schema: String
    var schemaVersion: Int
    var id: String
    var name: String
    var author: String
    var description: String?
    var license: String?
    var icon: String?
    var recommendedVolume: Double?
    var pitchVariation: Double?
    var events: [String: [PackClip]]

    init(
        schema: String = PackManifest.schemaName,
        schemaVersion: Int = PackManifest.schemaVersion,
        id: String,
        name: String,
        author: String,
        description: String? = nil,
        license: String? = nil,
        icon: String? = nil,
        recommendedVolume: Double? = nil,
        pitchVariation: Double? = nil,
        events: [String: [PackClip]]
    ) {
        self.schema = schema
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.author = author
        self.description = description
        self.license = license
        self.icon = icon
        self.recommendedVolume = recommendedVolume
        self.pitchVariation = pitchVariation
        self.events = events
    }

    var keyboardEventCount: Int {
        events.keys.filter { $0.hasPrefix("key.") }.count
    }

    var trackpadEventCount: Int {
        events.keys.filter { $0.hasPrefix("trackpad.") }.count
    }

    var audioFilePaths: [String] {
        Array(Set(events.values.flatMap { $0.map(\.file) })).sorted()
    }
}

struct PackClip: Codable, Equatable, Hashable {
    var file: String
    var startMs: Double?
    var durationMs: Double?
    var gain: Double?
    var pitchSemitones: Double?

    init(file: String, startMs: Double? = nil, durationMs: Double? = nil, gain: Double? = nil, pitchSemitones: Double? = nil) {
        self.file = file
        self.startMs = startMs
        self.durationMs = durationMs
        self.gain = gain
        self.pitchSemitones = pitchSemitones
    }
}

struct PackProvenance: Codable, Equatable {
    static let fileName = "tactilemac.import.json"
    static let converterVersion = "1"

    var sourceFormat: PackSourceFormat
    var sourceConfig: String
    var converterVersion: String
    var importedAt: Date
    var warnings: [String]
    var detectedVersion: String?
}

enum PackSourceFormat: String, Codable, CaseIterable {
    case tactilemac
    case legacyV1
    case legacyV2
    case extendedV2

    var title: String {
        switch self {
        case .tactilemac: return "TactileMac"
        case .legacyV1: return "Legacy V1"
        case .legacyV2: return "Legacy V2"
        case .extendedV2: return "Extended V2"
        }
    }

    var shortTitle: String {
        switch self {
        case .tactilemac: return "Native"
        case .legacyV1: return "Legacy V1"
        case .legacyV2: return "Legacy V2"
        case .extendedV2: return "Extended V2"
        }
    }
}

struct InstalledPack: Identifiable, Equatable {
    let id: String
    let manifest: PackManifest
    let rootURL: URL
    let isBuiltIn: Bool
    let sourceFormat: PackSourceFormat
    let warnings: [String]
    let issue: String?

    var name: String { manifest.name }
    var author: String { manifest.author }
    var isUsable: Bool { issue == nil }
    var keyboardEventCount: Int { manifest.keyboardEventCount }
    var trackpadEventCount: Int { manifest.trackpadEventCount }
    var audioFileCount: Int { manifest.audioFilePaths.count }
}

struct ImportOutcome {
    let pack: InstalledPack
    let warnings: [String]
    let sourceFormat: PackSourceFormat
    let sourceDescription: String
}

struct ResolvedClip {
    let sample: DecodedAudio
    let startFrame: Int
    let frameCount: Int
    let gain: Float
    let pitchSemitones: Double
}

enum PackEvent {
    static let keyDownPrefix = "key.down."
    static let keyUpPrefix = "key.up."
    static let clickPrefix = "trackpad.click."
    static let scrollPrefix = "trackpad.scroll."

    static func isSupported(_ key: String) -> Bool {
        if key.hasPrefix(keyDownPrefix) || key.hasPrefix(keyUpPrefix) {
            let prefix = key.hasPrefix(keyDownPrefix) ? keyDownPrefix : keyUpPrefix
            let suffix = String(key.dropFirst(prefix.count))
            if suffix == "default" { return true }
            if KeyDescriptor.Category.allCases.contains(where: { $0.rawValue == suffix }) { return true }
            return KeyCodeMap.isKnownKeyName(suffix)
        }
        if key.hasPrefix(clickPrefix) {
            return ["left", "right", "middle", "default"].contains(String(key.dropFirst(clickPrefix.count)))
        }
        if key.hasPrefix(scrollPrefix) {
            return ["up", "down", "default"].contains(String(key.dropFirst(scrollPrefix.count)))
        }
        return false
    }

    static func click(_ button: MouseButtonName) -> [String] {
        ["trackpad.click.\(button.rawValue)", "trackpad.click.default"]
    }

    static func scroll(direction: String) -> [String] {
        ["trackpad.scroll.\(direction)", "trackpad.scroll.default"]
    }
}
