import Foundation

enum MouseButtonName: String {
    case left
    case right
    case middle
    case other
}

enum NormalizedInputEvent {
    case keyDown(code: Int64, isRepeat: Bool, timestamp: TimeInterval)
    case keyUp(code: Int64, timestamp: TimeInterval)
    case modifierChanged(code: Int64, isDown: Bool, timestamp: TimeInterval)
    case mouseButton(button: MouseButtonName, isDown: Bool, timestamp: TimeInterval)
    case scroll(deltaY: Double, isPrecise: Bool, isMomentum: Bool, timestamp: TimeInterval)
    case pointerMoved(x: Double, y: Double, timestamp: TimeInterval)
}

struct LiveInputSnapshot: Equatable {
    var lastEvent: LastEvent?
    var pressedKeyCodes: Set<Int64> = []
    var keyboardEventCount: Int = 0
    var trackpadEventCount: Int = 0
    var soundCount: Int = 0
    var hapticCount: Int = 0
    var droppedCount: Int = 0
    var secureInputActive: Bool = false
    var inputMonitoringGranted: Bool = false
    var lastEngineLatencyMs: Double?
    var averageEngineLatencyMs: Double?

    struct LastEvent: Equatable {
        enum Kind: String {
            case keyDown = "Key down"
            case keyUp = "Key up"
            case modifier = "Modifier"
            case click = "Click"
            case scroll = "Scroll"
            case pointer = "Pointer"
        }
        var kind: Kind
        var detail: String
        var timestamp: Date
    }
}
