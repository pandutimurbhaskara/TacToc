import SwiftUI

enum Theme {
    static let purple = Color(red: 0.56, green: 0.42, blue: 0.95)
    static let purpleDeep = Color(red: 0.36, green: 0.24, blue: 0.72)
    static let lavender = Color(red: 0.80, green: 0.73, blue: 1.0)
    static let teal = Color(red: 0.16, green: 0.72, blue: 0.68)
    static let tealDeep = Color(red: 0.06, green: 0.48, blue: 0.47)
    static let amber = Color(red: 0.92, green: 0.62, blue: 0.20)
    static let coral = Color(red: 0.90, green: 0.38, blue: 0.42)

    static let sidebarWidth: CGFloat = 220
    static let rightPanelWidth: CGFloat = 336
    static let cornerRadius: CGFloat = 18

    static var background: Color { Color(nsColor: .windowBackgroundColor) }
    static var sidebarBackground: Color { Color(nsColor: .underPageBackgroundColor) }
    static var divider: Color { Color(nsColor: .separatorColor) }

    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.055) : Color.white
    }

    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.06)
    }

    static func softPurple(_ scheme: ColorScheme) -> Color {
        purple.opacity(scheme == .dark ? 0.20 : 0.10)
    }

    static func softTeal(_ scheme: ColorScheme) -> Color {
        teal.opacity(scheme == .dark ? 0.20 : 0.11)
    }
}

struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat
    var content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Theme.cardBackground(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(Theme.cardStroke(colorScheme), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.05), radius: 14, x: 0, y: 6)
    }
}

struct PageHeader: View {
    var title: String
    var subtitle: String
    var badge: String? = nil
    var badgeColor: Color = Theme.purple
    var trailing: AnyView? = nil

    init(title: String, subtitle: String, badge: String? = nil, badgeColor: Color = Theme.purple, trailing: AnyView? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.badgeColor = badgeColor
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                    if let badge {
                        StatusPill(text: badge, color: badgeColor)
                    }
                }
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if let trailing { trailing }
        }
        .padding(.bottom, 4)
    }
}

struct StatusPill: View {
    var text: String
    var color: Color
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 9, weight: .bold)) }
            else { Circle().fill(color).frame(width: 6, height: 6) }
            Text(text)
                .font(.system(size: 10.5, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct InfoBanner: View {
    var title: String
    var message: String
    var systemImage: String = "info.circle"
    var tint: Color = Theme.purple
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(.callout, design: .rounded).weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if actionTitle != nil || secondaryTitle != nil {
                    HStack(spacing: 10) {
                        if let actionTitle, let action {
                            Button(actionTitle, action: action).buttonStyle(CompactButtonStyle())
                        }
                        if let secondaryTitle, let secondaryAction {
                            Button(secondaryTitle, action: secondaryAction).buttonStyle(CompactButtonStyle(tinted: false))
                        }
                    }
                    .padding(.top, 3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

struct ToggleRow: View {
    var title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var tint: Color = Theme.purple
    var disabled: Bool = false

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(tint)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }
}

struct SliderRow: View {
    var title: String
    var subtitle: String? = nil
    @Binding var value: Double
    var range: ClosedRange<Double>
    var display: String
    var tint: Color = Theme.purple

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.callout)
                Spacer()
                Text(display)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
                .tint(tint)
            if let subtitle {
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

struct PickerRow<SelectionValue: Hashable, Content: View>: View {
    var title: String
    @Binding var selection: SelectionValue
    var content: Content

    init(title: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.callout)
            Picker(title, selection: $selection) { content }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct KeyValueRow: View {
    var label: String
    var value: String
    var color: Color? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(color ?? .primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var detail: String? = nil
    var tint: Color = Theme.purple
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            if let detail {
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(tint.opacity(0.12), lineWidth: 1))
    }
}

struct CompactButtonStyle: ButtonStyle {
    var tinted = true
    var tint: Color = Theme.purple

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(tinted ? tint.opacity(configuration.isPressed ? 0.24 : 0.14) : Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06),
                        in: Capsule())
            .foregroundStyle(tinted ? tint : Color.primary)
            .contentShape(Capsule())
    }
}

struct MiniActionButtonStyle: ButtonStyle {
    var tint: Color = Theme.purple
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(configuration.isPressed ? 0.22 : (selected ? 0.18 : 0.09)), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(selected ? 0.28 : 0.10), lineWidth: 1))
            .foregroundStyle(tint)
            .contentShape(Capsule())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.purple
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .padding(.horizontal, compact ? 13 : 17)
            .padding(.vertical, compact ? 7 : 9)
            .background(tint.opacity(configuration.isPressed ? 0.85 : 1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(.white)
            .shadow(color: tint.opacity(0.25), radius: 6, y: 3)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.purple
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .padding(.horizontal, compact ? 13 : 17)
            .padding(.vertical, compact ? 7 : 9)
            .background(tint.opacity(configuration.isPressed ? 0.20 : 0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(tint.opacity(0.22), lineWidth: 1))
            .foregroundStyle(tint)
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.9)
            .foregroundStyle(.secondary)
    }
}

struct CopyableErrorBox: View {
    var text: String
    var tint: Color = Theme.coral

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct IconTile: View {
    var systemImage: String
    var tint: Color = Theme.purple
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.30, style: .continuous))
    }
}
