import AppKit
import Foundation

protocol HapticPlaying: AnyObject {
    var isEnhancedAvailable: Bool { get }
    func tick(_ pattern: HapticPatternName)
    func pulse(material: HapticMaterialName, intensity: Double, useEnhanced: Bool)
    func previewMaterial(_ material: HapticMaterialName, intensity: Double, useEnhanced: Bool)
}

extension HapticPlaying {
    var isEnhancedAvailable: Bool { false }

    func pulse(material: HapticMaterialName, intensity: Double, useEnhanced: Bool) {
        tick(material.publicPattern(for: intensity))
    }

    func previewMaterial(_ material: HapticMaterialName, intensity: Double, useEnhanced: Bool) {
        tick(material.publicPattern(for: intensity))
    }
}

/// Public AppKit is always available as a fallback. The enhanced path is an
/// isolated, runtime-probed private adapter; if it cannot open an actuator,
/// every call falls back to NSHapticFeedbackManager.
final class HapticEngine: HapticPlaying {
    private let performer = NSHapticFeedbackManager.defaultPerformer
    private let privateEngine = PrivateActuatorEngine.shared
    private let privateQueue = DispatchQueue(label: "com.tactilemac.haptics.private", qos: .userInteractive)

    var isEnhancedAvailable: Bool { privateEngine.isAvailable }

    func tick(_ pattern: HapticPatternName) {
        let work = { [performer] in
            performer.perform(pattern.feedbackPattern, performanceTime: .now)
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    func pulse(material: HapticMaterialName, intensity: Double, useEnhanced: Bool) {
        if useEnhanced && privateEngine.isAvailable {
            let actuationID = material.actuationID(for: intensity)
            privateQueue.async { [privateEngine] in
                privateEngine.pulse(actuationID)
            }
        } else {
            tick(material.publicPattern(for: intensity))
        }
    }

    /// A short material phrase, long enough to feel the rhythm. This also
    /// verifies the selected actuator path without requiring a keyboard event.
    func previewMaterial(_ material: HapticMaterialName, intensity: Double, useEnhanced: Bool) {
        let gap = max(0.07, material.minimumInterval * 2.0)
        for index in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * gap) { [weak self] in
                self?.pulse(material: material, intensity: intensity, useEnhanced: useEnhanced)
            }
        }
    }
}

private extension HapticPatternName {
    var feedbackPattern: NSHapticFeedbackManager.FeedbackPattern {
        switch self {
        case .generic: return .generic
        case .alignment: return .alignment
        case .levelChange: return .levelChange
        }
    }
}
