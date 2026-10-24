import Foundation

/// A material is a rhythm/strength approximation, not a sampled surface.
/// Public AppKit cannot create arbitrary actuator waveforms; the enhanced
/// path maps materials onto the three private actuator strengths and changes
/// pulse spacing, cadence, and irregularity.
enum HapticMaterialName: String, Codable, CaseIterable, Identifiable {
    case felt
    case boucle
    case pebbled
    case fineGrit
    case softGrid
    case lineGrid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .felt: return "Felt"
        case .boucle: return "Bouclé"
        case .pebbled: return "Pebbled"
        case .fineGrit: return "Fine grit"
        case .softGrid: return "Soft grid"
        case .lineGrid: return "Line grid"
        }
    }

    var detail: String {
        switch self {
        case .felt: return "Soft, dense pulses with a little irregularity."
        case .boucle: return "Small loops and a looser, alternating rhythm."
        case .pebbled: return "Distinct, firmer bumps spaced further apart."
        case .fineGrit: return "A quick, fine stream of light pulses."
        case .softGrid: return "Regular, evenly spaced soft pulses."
        case .lineGrid: return "Regular ridges with a firmer pulse."
        }
    }

    var systemImage: String {
        switch self {
        case .felt: return "circle.grid.3x3.fill"
        case .boucle: return "circle.dashed.inset.filled"
        case .pebbled: return "circle.grid.2x2.fill"
        case .fineGrit: return "circle.dotted"
        case .softGrid: return "square.grid.3x3.fill"
        case .lineGrid: return "line.3.horizontal"
        }
    }

    /// Cursor distance, in points, between pulses.
    var spacing: Double {
        switch self {
        case .felt: return 8
        case .boucle: return 12
        case .pebbled: return 18
        case .fineGrit: return 5
        case .softGrid: return 12
        case .lineGrid: return 20
        }
    }

    /// Scroll delta between pulses.
    var scrollSpacing: Double {
        switch self {
        case .felt: return 2.0
        case .boucle: return 2.4
        case .pebbled: return 3.2
        case .fineGrit: return 1.2
        case .softGrid: return 2.2
        case .lineGrid: return 3.0
        }
    }

    /// Hard cap on pulse cadence.
    var minimumInterval: TimeInterval {
        switch self {
        case .felt: return 0.040
        case .boucle: return 0.045
        case .pebbled: return 0.060
        case .fineGrit: return 0.035
        case .softGrid: return 0.045
        case .lineGrid: return 0.065
        }
    }

    /// Shifts the selected intensity before it is mapped to an actuator preset.
    var strengthBias: Double {
        switch self {
        case .felt: return -0.12
        case .boucle: return 0.02
        case .pebbled: return 0.22
        case .fineGrit: return -0.28
        case .softGrid: return 0.0
        case .lineGrid: return 0.15
        }
    }

    var jitter: Double {
        switch self {
        case .felt: return 0.18
        case .boucle: return 0.40
        case .pebbled: return 0.50
        case .fineGrit: return 0.10
        case .softGrid: return 0.0
        case .lineGrid: return 0.0
        }
    }

    /// Private actuator IDs observed in the research build: 3 weak, 4 medium, 6 strong.
    func actuationID(for intensity: Double) -> Int32 {
        let value = min(max(intensity + strengthBias, 0), 1)
        if value < 0.34 { return 3 }
        if value < 0.67 { return 4 }
        return 6
    }

    /// Public AppKit fallback has only three fixed presets.
    func publicPattern(for intensity: Double) -> HapticPatternName {
        let value = min(max(intensity + strengthBias, 0), 1)
        if value < 0.34 { return .alignment }
        if value < 0.67 { return .generic }
        return .levelChange
    }
}
