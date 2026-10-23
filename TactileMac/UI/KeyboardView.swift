import SwiftUI

struct KeyboardView: View {
    var highlightedKey: String? = nil
    var highlightToken: Int = 0
    @Environment(\.colorScheme) private var colorScheme

    private enum Row {
        case function, numbers, top, home, bottom, modifiers
    }

    private struct Key: Identifiable {
        let id: String
        let label: String
        let units: CGFloat
        let tint: Color?
    }

    private var rows: [(Row, [Key])] {
        [
            (.function, [
                Key(id: "esc", label: "esc", units: 1, tint: nil),
                Key(id: "f1", label: "F1", units: 1, tint: nil), Key(id: "f2", label: "F2", units: 1, tint: nil),
                Key(id: "f3", label: "F3", units: 1, tint: nil), Key(id: "f4", label: "F4", units: 1, tint: nil),
                Key(id: "f5", label: "F5", units: 1, tint: nil), Key(id: "f6", label: "F6", units: 1, tint: nil),
                Key(id: "f7", label: "F7", units: 1, tint: nil), Key(id: "f8", label: "F8", units: 1, tint: nil),
                Key(id: "f9", label: "F9", units: 1, tint: nil), Key(id: "f10", label: "F10", units: 1, tint: nil),
                Key(id: "f11", label: "F11", units: 1, tint: nil), Key(id: "f12", label: "F12", units: 1, tint: nil)
            ]),
            (.numbers, [
                Key(id: "tilde", label: "`", units: 1, tint: nil), Key(id: "1", label: "1", units: 1, tint: nil),
                Key(id: "2", label: "2", units: 1, tint: nil), Key(id: "3", label: "3", units: 1, tint: nil),
                Key(id: "4", label: "4", units: 1, tint: nil), Key(id: "5", label: "5", units: 1, tint: nil),
                Key(id: "6", label: "6", units: 1, tint: nil), Key(id: "7", label: "7", units: 1, tint: nil),
                Key(id: "8", label: "8", units: 1, tint: nil), Key(id: "9", label: "9", units: 1, tint: nil),
                Key(id: "0", label: "0", units: 1, tint: nil), Key(id: "minus", label: "−", units: 1, tint: nil),
                Key(id: "equal", label: "=", units: 1, tint: nil), Key(id: "delete", label: "delete", units: 1.5, tint: nil)
            ]),
            (.top, [
                Key(id: "tab", label: "tab", units: 1.5, tint: nil),
                Key(id: "q", label: "Q", units: 1, tint: nil), Key(id: "w", label: "W", units: 1, tint: nil),
                Key(id: "e", label: "E", units: 1, tint: nil), Key(id: "r", label: "R", units: 1, tint: nil),
                Key(id: "t", label: "T", units: 1, tint: nil), Key(id: "y", label: "Y", units: 1, tint: nil),
                Key(id: "u", label: "U", units: 1, tint: nil), Key(id: "i", label: "I", units: 1, tint: nil),
                Key(id: "o", label: "O", units: 1, tint: nil), Key(id: "p", label: "P", units: 1, tint: nil),
                Key(id: "leftbracket", label: "[", units: 1, tint: nil), Key(id: "rightbracket", label: "]", units: 1, tint: nil),
                Key(id: "backslash", label: "\\", units: 1.5, tint: nil)
            ]),
            (.home, [
                Key(id: "caps", label: "caps lock", units: 1.8, tint: nil),
                Key(id: "a", label: "A", units: 1, tint: nil), Key(id: "s", label: "S", units: 1, tint: nil),
                Key(id: "d", label: "D", units: 1, tint: nil), Key(id: "f", label: "F", units: 1, tint: nil),
                Key(id: "g", label: "G", units: 1, tint: Theme.purple),
                Key(id: "h", label: "H", units: 1, tint: nil), Key(id: "j", label: "J", units: 1, tint: nil),
                Key(id: "k", label: "K", units: 1, tint: nil), Key(id: "l", label: "L", units: 1, tint: nil),
                Key(id: "semicolon", label: ";", units: 1, tint: nil), Key(id: "quote", label: "'", units: 1, tint: nil),
                Key(id: "return", label: "return", units: 2.2, tint: nil)
            ]),
            (.bottom, [
                Key(id: "shift", label: "shift", units: 2.4, tint: nil),
                Key(id: "z", label: "Z", units: 1, tint: nil), Key(id: "x", label: "X", units: 1, tint: nil),
                Key(id: "c", label: "C", units: 1, tint: nil), Key(id: "v", label: "V", units: 1, tint: nil),
                Key(id: "b", label: "B", units: 1, tint: nil), Key(id: "n", label: "N", units: 1, tint: nil),
                Key(id: "m", label: "M", units: 1, tint: nil), Key(id: "comma", label: ",", units: 1, tint: nil),
                Key(id: "period", label: ".", units: 1, tint: nil), Key(id: "slash", label: "/", units: 1, tint: nil),
                Key(id: "rshift", label: "shift", units: 2.4, tint: nil)
            ]),
            (.modifiers, [
                Key(id: "fn", label: "fn", units: 1, tint: nil),
                Key(id: "ctrl", label: "control", units: 1, tint: nil),
                Key(id: "opt", label: "option", units: 1, tint: nil),
                Key(id: "cmd", label: "command", units: 1, tint: nil),
                Key(id: "spacebar", label: "space", units: 5.5, tint: Theme.purple),
                Key(id: "cmd2", label: "command", units: 1, tint: nil),
                Key(id: "opt2", label: "option", units: 1, tint: nil),
                Key(id: "left", label: "←", units: 0.8, tint: nil),
                Key(id: "down", label: "↓", units: 0.8, tint: nil),
                Key(id: "up", label: "↑", units: 0.8, tint: nil),
                Key(id: "right", label: "→", units: 0.8, tint: nil)
            ])
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 4
            let totalUnits: CGFloat = 15.6
            let unit = max(14, (proxy.size.width - gap * 13) / totalUnits)
            VStack(alignment: .leading, spacing: gap) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: gap) {
                        ForEach(row.1) { key in
                            keyCap(key, unit: unit, gap: gap)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(2.72, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Decorative keyboard visualization. Use the preview buttons to play a key sound.")
    }

    private func keyCap(_ key: Key, unit: CGFloat, gap: CGFloat) -> some View {
        let width = unit * key.units + gap * (key.units - 1)
        let highlighted = highlightedKey == key.id || (key.id == "g" && highlightedKey == "letter")
        return RoundedRectangle(cornerRadius: max(5, unit * 0.16), style: .continuous)
            .fill(highlighted ? Theme.purple.opacity(colorScheme == .dark ? 0.60 : 0.20) : keyFill(for: key))
            .overlay(
                RoundedRectangle(cornerRadius: max(5, unit * 0.16), style: .continuous)
                    .stroke(highlighted ? Theme.purple.opacity(0.9) : Theme.cardStroke(colorScheme), lineWidth: highlighted ? 1.5 : 0.8)
            )
            .overlay(
                Text(key.label)
                    .font(.system(size: max(7, min(10.5, unit * 0.30)), weight: .medium, design: .rounded))
                    .foregroundStyle(highlighted ? Theme.purple : (key.tint ?? .secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 2)
            )
            .frame(width: width, height: unit)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 1.5, y: 1.5)
            .scaleEffect(highlighted ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.62), value: highlighted)
    }

    private func keyFill(for key: Key) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(key.tint == nil ? 0.060 : 0.10)
        }
        let base = NSColor.controlBackgroundColor.blended(withFraction: 0.18, of: .white) ?? .controlBackgroundColor
        return Color(nsColor: base)
    }
}

private extension NSColor {
    func blended(withFraction fraction: CGFloat, of color: NSColor) -> NSColor? {
        guard let a = usingColorSpace(.deviceRGB), let b = color.usingColorSpace(.deviceRGB) else { return nil }
        return NSColor(
            red: a.redComponent + (b.redComponent - a.redComponent) * fraction,
            green: a.greenComponent + (b.greenComponent - a.greenComponent) * fraction,
            blue: a.blueComponent + (b.blueComponent - a.blueComponent) * fraction,
            alpha: 1
        )
    }
}
