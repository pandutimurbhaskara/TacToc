import Foundation

enum LegacyKeyMap {
    /// Windows virtual-key numbers used by legacy configs, mapped to W3C
    /// `KeyboardEvent.code` names. Extended values follow the documented
    /// legacy key table, including the Darwin remaps.
    private static let legacyCodes: [String: String] = [
        "1": "Escape",
        "2": "Digit1", "3": "Digit2", "4": "Digit3", "5": "Digit4", "6": "Digit5",
        "7": "Digit6", "8": "Digit7", "9": "Digit8", "10": "Digit9", "11": "Digit0",
        "12": "Minus", "13": "Equal", "14": "Backspace", "15": "Tab",
        "16": "KeyQ", "17": "KeyW", "18": "KeyE", "19": "KeyR", "20": "KeyT",
        "21": "KeyY", "22": "KeyU", "23": "KeyI", "24": "KeyO", "25": "KeyP",
        "26": "BracketLeft", "27": "BracketRight", "28": "Enter", "29": "ControlLeft",
        "30": "KeyA", "31": "KeyS", "32": "KeyD", "33": "KeyF", "34": "KeyG",
        "35": "KeyH", "36": "KeyJ", "37": "KeyK", "38": "KeyL", "39": "Semicolon",
        "40": "Quote", "41": "Backquote", "42": "ShiftLeft", "43": "Backslash",
        "44": "KeyZ", "45": "KeyX", "46": "KeyC", "47": "KeyV", "48": "KeyB",
        "49": "KeyN", "50": "KeyM", "51": "Comma", "52": "Period", "53": "Slash",
        "54": "ShiftRight", "55": "NumpadMultiply", "56": "AltLeft", "57": "Space",
        "58": "CapsLock", "59": "F1", "60": "F2", "61": "F3", "62": "F4",
        "63": "F5", "64": "F6", "65": "F7", "66": "F8", "67": "F9", "68": "F10",
        "69": "NumLock", "70": "F14", "71": "Numpad7", "72": "Numpad8", "73": "Numpad9",
        "74": "NumpadSubtract", "75": "Numpad4", "76": "Numpad5", "77": "Numpad6",
        "78": "NumpadAdd", "79": "Numpad1", "80": "Numpad2", "81": "Numpad3",
        "82": "Numpad0", "83": "NumpadDecimal", "87": "F11", "88": "F12",
        "91": "F13", "92": "F14", "93": "F15",

        // Extended scancodes emitted on some platforms.
        "3597": "NumpadEqual",
        "3612": "NumpadEnter",
        "3613": "ControlRight",
        "3637": "NumpadDivide",
        "3639": "F13",
        "3640": "AltRight",
        "3653": "F15",
        "3655": "Home",
        "3657": "PageUp",
        "3663": "End",
        "3665": "PageDown",
        "3666": "Help",
        "3667": "Delete",
        "3675": "MetaLeft",
        "3676": "MetaRight",
        "3677": "ContextMenu",

        "57416": "ArrowUp", "57419": "ArrowLeft", "57421": "ArrowRight", "57424": "ArrowDown",

        "60999": "Home",
        "61000": "ArrowUp",
        "61001": "PageUp",
        "61003": "ArrowLeft",
        "61005": "ArrowRight",
        "61007": "End",
        "61008": "ArrowDown",
        "61009": "PageDown",
        "61010": "Help",
        "61011": "Delete"
    ]

    static func w3cName(forLegacyCode raw: String) -> String? {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name = legacyCodes[code] { return name }
        if KeyCodeMap.isKnownKeyName(code) { return code }
        return nil
    }

    static func mouseButton(forLegacyCode raw: String) -> (MouseButtonName, isRelease: Bool)? {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let isRelease = code.count > 1 && code.hasPrefix("0")
        let numeric = Int(code) ?? -1
        switch numeric {
        case 1: return (.left, isRelease)
        case 2: return (.right, isRelease)
        case 3: return (.middle, isRelease)
        default: return nil
        }
    }

    static func isNumericCode(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.allSatisfy { $0.isNumber }
    }
}
