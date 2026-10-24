import Foundation

struct AppSettings: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = AppSettings.currentSchemaVersion

    var keyboardEnabled: Bool = true
    var keyboardVolume: Double = 0.65
    var playKeyUpSounds: Bool = true
    var playModifierSounds: Bool = true
    var playKeyRepeatSounds: Bool = false
    var keyboardPackID: String = "thock"

    var trackpadEnabled: Bool = true
    var trackpadVolume: Double = 0.55
    var trackpadClicksEnabled: Bool = true
    var trackpadScrollEnabled: Bool = true
    var trackpadPackID: String = "thock"
    var preciseScrollOnly: Bool = true
    var includeMomentumScroll: Bool = false
    var scrollMinimumIntervalMs: Double = 42
    var clickDebounceMs: Double = 45

    var hapticsEnabled: Bool = true
    var hapticOnKeyboard: Bool = false
    var hapticOnTrackpadClicks: Bool = true
    var hapticOnScroll: Bool = true
    var hapticOnPointerMovement: Bool = true
    var enhancedHaptics: Bool = true
    var hapticMaterial: HapticMaterialName = .felt
    var hapticIntensity: Double = 0.6
    var hapticPattern: HapticPatternName = .generic

    var pitchVariation: Double = 0.08
    var audioBufferFrames: Int = 256
    var showMenuBarExtra: Bool = true
    var hasSeenPermissionGuidance: Bool = false

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case keyboardEnabled, keyboardVolume, playKeyUpSounds, playModifierSounds, playKeyRepeatSounds, keyboardPackID
        case trackpadEnabled, trackpadVolume, trackpadClicksEnabled, trackpadScrollEnabled, trackpadPackID
        case preciseScrollOnly, includeMomentumScroll, scrollMinimumIntervalMs, clickDebounceMs
        case hapticsEnabled, hapticOnKeyboard, hapticOnTrackpadClicks, hapticOnScroll
        case hapticOnPointerMovement, enhancedHaptics, hapticMaterial, hapticIntensity, hapticPattern
        case pitchVariation, audioBufferFrames, showMenuBarExtra, hasSeenPermissionGuidance
    }

    init() {}

    init(from decoder: Decoder) throws {
        let defaults = AppSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? defaults.schemaVersion
        keyboardEnabled = try container.decodeIfPresent(Bool.self, forKey: .keyboardEnabled) ?? defaults.keyboardEnabled
        keyboardVolume = try container.decodeIfPresent(Double.self, forKey: .keyboardVolume) ?? defaults.keyboardVolume
        playKeyUpSounds = try container.decodeIfPresent(Bool.self, forKey: .playKeyUpSounds) ?? defaults.playKeyUpSounds
        playModifierSounds = try container.decodeIfPresent(Bool.self, forKey: .playModifierSounds) ?? defaults.playModifierSounds
        playKeyRepeatSounds = try container.decodeIfPresent(Bool.self, forKey: .playKeyRepeatSounds) ?? defaults.playKeyRepeatSounds
        keyboardPackID = try container.decodeIfPresent(String.self, forKey: .keyboardPackID) ?? defaults.keyboardPackID
        trackpadEnabled = try container.decodeIfPresent(Bool.self, forKey: .trackpadEnabled) ?? defaults.trackpadEnabled
        trackpadVolume = try container.decodeIfPresent(Double.self, forKey: .trackpadVolume) ?? defaults.trackpadVolume
        trackpadClicksEnabled = try container.decodeIfPresent(Bool.self, forKey: .trackpadClicksEnabled) ?? defaults.trackpadClicksEnabled
        trackpadScrollEnabled = try container.decodeIfPresent(Bool.self, forKey: .trackpadScrollEnabled) ?? defaults.trackpadScrollEnabled
        trackpadPackID = try container.decodeIfPresent(String.self, forKey: .trackpadPackID) ?? defaults.trackpadPackID
        preciseScrollOnly = try container.decodeIfPresent(Bool.self, forKey: .preciseScrollOnly) ?? defaults.preciseScrollOnly
        includeMomentumScroll = try container.decodeIfPresent(Bool.self, forKey: .includeMomentumScroll) ?? defaults.includeMomentumScroll
        scrollMinimumIntervalMs = try container.decodeIfPresent(Double.self, forKey: .scrollMinimumIntervalMs) ?? defaults.scrollMinimumIntervalMs
        clickDebounceMs = try container.decodeIfPresent(Double.self, forKey: .clickDebounceMs) ?? defaults.clickDebounceMs
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? defaults.hapticsEnabled
        hapticOnKeyboard = try container.decodeIfPresent(Bool.self, forKey: .hapticOnKeyboard) ?? defaults.hapticOnKeyboard
        hapticOnTrackpadClicks = try container.decodeIfPresent(Bool.self, forKey: .hapticOnTrackpadClicks) ?? defaults.hapticOnTrackpadClicks
        hapticOnScroll = try container.decodeIfPresent(Bool.self, forKey: .hapticOnScroll) ?? defaults.hapticOnScroll
        hapticOnPointerMovement = try container.decodeIfPresent(Bool.self, forKey: .hapticOnPointerMovement) ?? defaults.hapticOnPointerMovement
        enhancedHaptics = try container.decodeIfPresent(Bool.self, forKey: .enhancedHaptics) ?? defaults.enhancedHaptics
        hapticMaterial = try container.decodeIfPresent(HapticMaterialName.self, forKey: .hapticMaterial) ?? defaults.hapticMaterial
        hapticIntensity = try container.decodeIfPresent(Double.self, forKey: .hapticIntensity) ?? defaults.hapticIntensity
        hapticPattern = try container.decodeIfPresent(HapticPatternName.self, forKey: .hapticPattern) ?? defaults.hapticPattern
        pitchVariation = try container.decodeIfPresent(Double.self, forKey: .pitchVariation) ?? defaults.pitchVariation
        audioBufferFrames = try container.decodeIfPresent(Int.self, forKey: .audioBufferFrames) ?? defaults.audioBufferFrames
        showMenuBarExtra = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarExtra) ?? defaults.showMenuBarExtra
        hasSeenPermissionGuidance = try container.decodeIfPresent(Bool.self, forKey: .hasSeenPermissionGuidance) ?? defaults.hasSeenPermissionGuidance
        clamp()
    }

    mutating func clamp() {
        keyboardVolume = min(max(keyboardVolume, 0), 1)
        trackpadVolume = min(max(trackpadVolume, 0), 1)
        scrollMinimumIntervalMs = min(max(scrollMinimumIntervalMs, 16), 250)
        clickDebounceMs = min(max(clickDebounceMs, 10), 250)
        hapticIntensity = min(max(hapticIntensity, 0), 1)
        pitchVariation = min(max(pitchVariation, 0), 2)
        if ![128, 256, 512, 1024].contains(audioBufferFrames) { audioBufferFrames = 256 }
    }
}

enum HapticPatternName: String, Codable, CaseIterable, Identifiable {
    case generic
    case alignment
    case levelChange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .generic: return "Generic"
        case .alignment: return "Alignment"
        case .levelChange: return "Level Change"
        }
    }

    var detail: String {
        switch self {
        case .generic: return "Standard tap"
        case .alignment: return "Lighter alignment tick"
        case .levelChange: return "Strongest preset"
        }
    }
}
