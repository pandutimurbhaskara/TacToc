import SwiftUI

struct HapticsPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var pulseToken = 0

    private var enhancedActive: Bool {
        model.settings.enhancedHaptics && model.enhancedHapticsAvailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Haptics",
                subtitle: "Material-shaped pulses through the trackpad actuator, with an automatic public AppKit fallback.",
                badge: enhancedActive ? "Enhanced material" : "Public fallback",
                badgeColor: enhancedActive ? Theme.teal : Theme.purple
            )

            Card {
                HStack(alignment: .center, spacing: 18) {
                    HapticGlyphView(pulseToken: pulseToken)
                        .frame(width: 210)
                    VStack(alignment: .leading, spacing: 9) {
                        Text(model.trackpad.actuationReported ? "Haptic trackpad detected" : "Haptic capability check")
                            .font(.system(size: 21, weight: .semibold, design: .rounded))
                        Text(model.trackpad.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let product = model.trackpad.productName {
                            KeyValueRow(label: "Device", value: product)
                        }
                        KeyValueRow(
                            label: "Actuator path",
                            value: enhancedActive ? "Private enhanced (experimental)" : (model.settings.enhancedHaptics ? "Public fallback" : "Public AppKit"),
                            color: enhancedActive ? Theme.teal : Theme.purple
                        )
                        KeyValueRow(
                            label: "Private actuator",
                            value: model.enhancedHapticsAvailable ? "Available" : "Not available",
                            color: model.enhancedHapticsAvailable ? Theme.teal : Theme.amber
                        )
                        HStack(spacing: 10) {
                            Button {
                                pulseToken += 1
                                model.previewHaptic()
                            } label: {
                                Label("Test material", systemImage: "hand.point.up.left.fill")
                            }
                            .buttonStyle(PrimaryButtonStyle(tint: Theme.teal, compact: true))
                            .accessibilityIdentifier("haptics.test")
                            Button("Permissions & Hardware") { model.selectedPage = .permissions }
                                .buttonStyle(SecondaryButtonStyle(tint: Theme.teal, compact: true))
                        }
                        .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Material")
                                .font(.system(.headline, design: .rounded))
                            Text("A pulse rhythm and strength approximation. The glass stays smooth; no arbitrary actuator waveform is claimed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        StatusPill(text: "Experimental", color: Theme.teal)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 178), spacing: 10)], spacing: 10) {
                        ForEach(HapticMaterialName.allCases) { material in
                            MaterialTile(
                                material: material,
                                selected: model.settings.hapticMaterial == material
                            ) {
                                pulseToken += 1
                                model.previewMaterial(material)
                            }
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                MetricTile(
                    title: "Haptic ticks",
                    value: "\(model.input.hapticCount)",
                    detail: "This session",
                    tint: Theme.teal,
                    systemImage: "hand.point.up.left.fill"
                )
                MetricTile(
                    title: "Material",
                    value: model.settings.hapticMaterial.title,
                    detail: "Intensity \(Int(model.settings.hapticIntensity * 100))%",
                    tint: Theme.teal,
                    systemImage: "waveform.path"
                )
                MetricTile(
                    title: "Actuator",
                    value: enhancedActive ? "Enhanced" : "Fallback",
                    detail: model.enhancedHapticsAvailable ? "Private actuator available" : "Public AppKit only",
                    tint: Theme.teal,
                    systemImage: "switch.2"
                )
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What this implementation can and cannot do")
                        .font(.system(.headline, design: .rounded))
                    boundary("Material pulses", "Movement, scrolling, and taps are converted into discrete pulses. Spacing, cadence, and a small jitter shape the selected material.")
                    boundary("Strength", "Intensity maps to three observed actuator presets (weak, medium, strong). It is not a continuous amplitude parameter.")
                    boundary("Public fallback", "If the private actuator cannot be opened, AppKit's alignment/generic/level-change presets are used instead. The UI says Fallback instead of hiding it.")
                    boundary("No third-party code", "The actuator adapter is independent and isolated in Haptics/Experimental. No third-party implementation code or assets are used.")
                    boundary("Physical check", "The private actuator opened successfully on this Mac in a standalone probe. Material feel still requires an in-person test.")
                }
            }

            if model.settings.enhancedHaptics && !model.enhancedHapticsAvailable {
                InfoBanner(
                    title: "Enhanced actuator unavailable — using AppKit fallback",
                    message: "The private framework or an actuator could not be opened. Material pulses continue through the public preset path.",
                    systemImage: "exclamationmark.triangle",
                    tint: Theme.amber
                )
            }

            Card {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Theme.teal)
                        Text("Experimental path")
                            .font(.callout.weight(.semibold))
                    }
                    Text("The enhanced path loads Apple's private MultitouchSupport framework at runtime. It is isolated, probed, and falls back to public AppKit. It may change or disappear in a macOS update and is not an App Store-compatible promise.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func boundary(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.teal)
                .frame(width: 120, alignment: .leading)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MaterialTile: View {
    var material: HapticMaterialName
    var selected: Bool
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: material.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(selected ? Theme.teal : Theme.purple)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.teal)
                    }
                }
                Text(material.title)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                Text(material.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Theme.teal.opacity(colorScheme == .dark ? 0.16 : 0.10) : Theme.purple.opacity(colorScheme == .dark ? 0.08 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Theme.teal.opacity(0.55) : Theme.cardStroke(colorScheme), lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Select and preview \(material.title)")
        .accessibilityLabel("\(material.title) material. \(material.detail)")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityIdentifier("material.\(material.rawValue)")
    }
}

struct HapticsSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Card {
                VStack(alignment: .leading, spacing: 13) {
                    SectionLabel(text: "Material feedback")
                    ToggleRow(title: "Haptics", subtitle: "Trackpad and keyboard pulses", isOn: model.binding(\.hapticsEnabled), tint: Theme.teal)
                    Divider()
                    ToggleRow(
                        title: "Enhanced actuator",
                        subtitle: model.enhancedHapticsAvailable ? "Private MultitouchSupport; experimental" : "Unavailable; using public AppKit",
                        isOn: model.binding(\.enhancedHaptics),
                        tint: Theme.teal,
                        disabled: !model.enhancedHapticsAvailable
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Material").font(.callout)
                        Picker("Material", selection: model.binding(\.hapticMaterial)) {
                            ForEach(HapticMaterialName.allCases) { material in
                                Text(material.title).tag(material)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    SliderRow(
                        title: "Intensity",
                        subtitle: "Maps to weak / medium / strong actuator presets",
                        value: model.binding(\.hapticIntensity),
                        range: 0...1,
                        display: "\(Int(model.settings.hapticIntensity * 100))%",
                        tint: Theme.teal
                    )
                    Text(model.settings.enhancedHaptics && model.enhancedHapticsAvailable
                         ? "Private actuator active. The material is a pulse rhythm, not a continuous waveform."
                         : "Public AppKit fallback: three fixed patterns with no intensity parameter.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Triggers")
                    ToggleRow(title: "Pointer movement", subtitle: "Pulses as the cursor travels", isOn: model.binding(\.hapticOnPointerMovement), tint: Theme.teal)
                    ToggleRow(title: "Scroll ticks", subtitle: "Material pulses while two-finger scrolling", isOn: model.binding(\.hapticOnScroll), tint: Theme.teal)
                    ToggleRow(title: "Trackpad clicks", subtitle: "One pulse on button down", isOn: model.binding(\.hapticOnTrackpadClicks), tint: Theme.teal)
                    ToggleRow(title: "Keyboard ticks", subtitle: "On key down and modifier presses", isOn: model.binding(\.hapticOnKeyboard), tint: Theme.teal)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Hardware")
                    KeyValueRow(
                        label: "Trackpad",
                        value: model.trackpad.actuationReported ? "Actuation reported" : (model.trackpad.detected ? "Detected" : "Not detected"),
                        color: model.trackpad.detected ? Theme.teal : Theme.amber
                    )
                    KeyValueRow(
                        label: "Private actuator",
                        value: model.enhancedHapticsAvailable ? "Available" : "Unavailable",
                        color: model.enhancedHapticsAvailable ? Theme.teal : Theme.amber
                    )
                    KeyValueRow(label: "Active path", value: model.settings.enhancedHaptics && model.enhancedHapticsAvailable ? "Enhanced" : "Public fallback")
                    Button {
                        model.previewHaptic()
                    } label: {
                        Label("Test material", systemImage: "hand.point.up.left.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.teal, compact: true))
                    .accessibilityIdentifier("haptics.settings.test")
                    Text("Keep a finger resting on the trackpad while testing. The app cannot determine whether you felt the pulse.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
