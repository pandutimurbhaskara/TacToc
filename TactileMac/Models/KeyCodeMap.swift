import Foundation

struct KeyDescriptor: Hashable {
    enum Category: String, CaseIterable {
        case letter
        case number
        case punctuation
        case modifier
        case function
        case navigation
        case numpad
        case space
        case enter
        case backspace
        case escape
        case other
    }

    let code: Int64
    let w3cName: String
    let label: String
    let category: Category

    var downEvents: [String] {
        ["key.down.\(w3cName)", "key.down.\(category.rawValue)", "key.down.default"]
    }

    var upEvents: [String] {
        ["key.up.\(w3cName)", "key.up.\(category.rawValue)", "key.up.default"]
    }
}

enum KeyCodeMap {
    private struct Entry {
        let code: Int64
        let name: String
        let label: String
        let category: KeyDescriptor.Category
    }

    private static let entries: [Entry] = [
        // Letters
        Entry(code: 0, name: "KeyA", label: "A", category: .letter),
        Entry(code: 1, name: "KeyS", label: "S", category: .letter),
        Entry(code: 2, name: "KeyD", label: "D", category: .letter),
        Entry(code: 3, name: "KeyF", label: "F", category: .letter),
        Entry(code: 4, name: "KeyH", label: "H", category: .letter),
        Entry(code: 5, name: "KeyG", label: "G", category: .letter),
        Entry(code: 6, name: "KeyZ", label: "Z", category: .letter),
        Entry(code: 7, name: "KeyX", label: "X", category: .letter),
        Entry(code: 8, name: "KeyC", label: "C", category: .letter),
        Entry(code: 9, name: "KeyV", label: "V", category: .letter),
        Entry(code: 11, name: "KeyB", label: "B", category: .letter),
        Entry(code: 12, name: "KeyQ", label: "Q", category: .letter),
        Entry(code: 13, name: "KeyW", label: "W", category: .letter),
        Entry(code: 14, name: "KeyE", label: "E", category: .letter),
        Entry(code: 15, name: "KeyR", label: "R", category: .letter),
        Entry(code: 16, name: "KeyY", label: "Y", category: .letter),
        Entry(code: 17, name: "KeyT", label: "T", category: .letter),
        Entry(code: 31, name: "KeyO", label: "O", category: .letter),
        Entry(code: 32, name: "KeyU", label: "U", category: .letter),
        Entry(code: 34, name: "KeyI", label: "I", category: .letter),
        Entry(code: 35, name: "KeyP", label: "P", category: .letter),
        Entry(code: 37, name: "KeyL", label: "L", category: .letter),
        Entry(code: 38, name: "KeyJ", label: "J", category: .letter),
        Entry(code: 40, name: "KeyK", label: "K", category: .letter),
        Entry(code: 45, name: "KeyN", label: "N", category: .letter),
        Entry(code: 46, name: "KeyM", label: "M", category: .letter),

        // Number row and punctuation
        Entry(code: 18, name: "Digit1", label: "1", category: .number),
        Entry(code: 19, name: "Digit2", label: "2", category: .number),
        Entry(code: 20, name: "Digit3", label: "3", category: .number),
        Entry(code: 21, name: "Digit4", label: "4", category: .number),
        Entry(code: 22, name: "Digit6", label: "6", category: .number),
        Entry(code: 23, name: "Digit5", label: "5", category: .number),
        Entry(code: 25, name: "Digit9", label: "9", category: .number),
        Entry(code: 26, name: "Digit7", label: "7", category: .number),
        Entry(code: 28, name: "Digit8", label: "8", category: .number),
        Entry(code: 29, name: "Digit0", label: "0", category: .number),
        Entry(code: 24, name: "Equal", label: "=", category: .punctuation),
        Entry(code: 27, name: "Minus", label: "-", category: .punctuation),
        Entry(code: 30, name: "BracketRight", label: "]", category: .punctuation),
        Entry(code: 33, name: "BracketLeft", label: "[", category: .punctuation),
        Entry(code: 39, name: "Quote", label: "'", category: .punctuation),
        Entry(code: 41, name: "Semicolon", label: ";", category: .punctuation),
        Entry(code: 42, name: "Backslash", label: "\\", category: .punctuation),
        Entry(code: 43, name: "Comma", label: ",", category: .punctuation),
        Entry(code: 44, name: "Slash", label: "/", category: .punctuation),
        Entry(code: 47, name: "Period", label: ".", category: .punctuation),
        Entry(code: 50, name: "Backquote", label: "`", category: .punctuation),

        // Specials
        Entry(code: 36, name: "Enter", label: "Return", category: .enter),
        Entry(code: 76, name: "NumpadEnter", label: "Enter", category: .enter),
        Entry(code: 48, name: "Tab", label: "Tab", category: .other),
        Entry(code: 49, name: "Space", label: "Space", category: .space),
        Entry(code: 51, name: "Backspace", label: "Delete", category: .backspace),
        Entry(code: 117, name: "Delete", label: "Forward Delete", category: .backspace),
        Entry(code: 53, name: "Escape", label: "Esc", category: .escape),
        Entry(code: 57, name: "CapsLock", label: "Caps Lock", category: .modifier),

        // Modifiers
        Entry(code: 54, name: "MetaRight", label: "Right Command", category: .modifier),
        Entry(code: 55, name: "MetaLeft", label: "Command", category: .modifier),
        Entry(code: 56, name: "ShiftLeft", label: "Shift", category: .modifier),
        Entry(code: 60, name: "ShiftRight", label: "Right Shift", category: .modifier),
        Entry(code: 58, name: "AltLeft", label: "Option", category: .modifier),
        Entry(code: 61, name: "AltRight", label: "Right Option", category: .modifier),
        Entry(code: 59, name: "ControlLeft", label: "Control", category: .modifier),
        Entry(code: 62, name: "ControlRight", label: "Right Control", category: .modifier),
        Entry(code: 63, name: "Fn", label: "Fn", category: .modifier),

        // Navigation
        Entry(code: 115, name: "Home", label: "Home", category: .navigation),
        Entry(code: 119, name: "End", label: "End", category: .navigation),
        Entry(code: 116, name: "PageUp", label: "Page Up", category: .navigation),
        Entry(code: 121, name: "PageDown", label: "Page Down", category: .navigation),
        Entry(code: 123, name: "ArrowLeft", label: "Left", category: .navigation),
        Entry(code: 124, name: "ArrowRight", label: "Right", category: .navigation),
        Entry(code: 125, name: "ArrowDown", label: "Down", category: .navigation),
        Entry(code: 126, name: "ArrowUp", label: "Up", category: .navigation),
        Entry(code: 114, name: "Help", label: "Help", category: .navigation),

        // Function keys
        Entry(code: 122, name: "F1", label: "F1", category: .function),
        Entry(code: 120, name: "F2", label: "F2", category: .function),
        Entry(code: 99, name: "F3", label: "F3", category: .function),
        Entry(code: 118, name: "F4", label: "F4", category: .function),
        Entry(code: 96, name: "F5", label: "F5", category: .function),
        Entry(code: 97, name: "F6", label: "F6", category: .function),
        Entry(code: 98, name: "F7", label: "F7", category: .function),
        Entry(code: 100, name: "F8", label: "F8", category: .function),
        Entry(code: 101, name: "F9", label: "F9", category: .function),
        Entry(code: 109, name: "F10", label: "F10", category: .function),
        Entry(code: 103, name: "F11", label: "F11", category: .function),
        Entry(code: 111, name: "F12", label: "F12", category: .function),
        Entry(code: 105, name: "F13", label: "F13", category: .function),
        Entry(code: 107, name: "F14", label: "F14", category: .function),
        Entry(code: 113, name: "F15", label: "F15", category: .function),
        Entry(code: 106, name: "F16", label: "F16", category: .function),
        Entry(code: 64, name: "F17", label: "F17", category: .function),
        Entry(code: 79, name: "F18", label: "F18", category: .function),
        Entry(code: 80, name: "F19", label: "F19", category: .function),
        Entry(code: 90, name: "F20", label: "F20", category: .function),

        // Keypad
        Entry(code: 65, name: "NumpadDecimal", label: ".", category: .numpad),
        Entry(code: 67, name: "NumpadMultiply", label: "*", category: .numpad),
        Entry(code: 69, name: "NumpadAdd", label: "+", category: .numpad),
        Entry(code: 71, name: "NumLock", label: "Clear", category: .numpad),
        Entry(code: 75, name: "NumpadDivide", label: "/", category: .numpad),
        Entry(code: 78, name: "NumpadSubtract", label: "-", category: .numpad),
        Entry(code: 81, name: "NumpadEqual", label: "=", category: .numpad),
        Entry(code: 82, name: "Numpad0", label: "0", category: .numpad),
        Entry(code: 83, name: "Numpad1", label: "1", category: .numpad),
        Entry(code: 84, name: "Numpad2", label: "2", category: .numpad),
        Entry(code: 85, name: "Numpad3", label: "3", category: .numpad),
        Entry(code: 86, name: "Numpad4", label: "4", category: .numpad),
        Entry(code: 87, name: "Numpad5", label: "5", category: .numpad),
        Entry(code: 88, name: "Numpad6", label: "6", category: .numpad),
        Entry(code: 89, name: "Numpad7", label: "7", category: .numpad),
        Entry(code: 91, name: "Numpad8", label: "8", category: .numpad),
        Entry(code: 92, name: "Numpad9", label: "9", category: .numpad)
    ]

    private static let byCode: [Int64: KeyDescriptor] = {
        Dictionary(uniqueKeysWithValues: entries.map {
            ($0.code, KeyDescriptor(code: $0.code, w3cName: $0.name, label: $0.label, category: $0.category))
        })
    }()

    private static let byName: [String: KeyDescriptor] = {
        Dictionary(uniqueKeysWithValues: entries.map {
            ($0.name, KeyDescriptor(code: $0.code, w3cName: $0.name, label: $0.label, category: $0.category))
        })
    }()

    static func descriptor(for code: Int64) -> KeyDescriptor? { byCode[code] }
    static func descriptor(named name: String) -> KeyDescriptor? { byName[name] }
    static func macKeyCode(forW3C name: String) -> Int64? { byName[name]?.code }
    static func isKnownKeyName(_ name: String) -> Bool { byName[name] != nil }
    static var knownNames: [String] { byName.keys.sorted() }

    static func label(for code: Int64) -> String {
        byCode[code]?.label ?? "#\(code)"
    }
}
