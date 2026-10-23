import AppKit
import Foundation

protocol HapticPlaying: AnyObject {
    func tick(_ pattern: HapticPatternName)
}

/// Public AppKit haptics only.
///
/// `NSHapticFeedbackManager` exposes three predefined patterns and a
/// performance-time hint. It does not expose an intensity parameter, arbitrary
/// waveforms, or a capability query. We therefore never present an intensity
/// slider as if it were a hardware control.
final class HapticEngine: HapticPlaying {
    private let performer = NSHapticFeedbackManager.defaultPerformer

    func tick(_ pattern: HapticPatternName) {
        let work = { [performer] in
            performer.perform(pattern.feedbackPattern, performanceTime: .now)
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
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
