import SwiftUI

struct HapticsPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var pulseToken = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Haptics",
                subtitle: "Physical feedback through AppKit's public haptic performer, independent of audio.",
                badge: "Public API",
                badgeColor: Theme.teal
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
                        KeyValueRow(label: "Public patterns", value: "3 presets")
                        KeyValueRow(label: "Intensity API", value: "Not exposed by AppKit")
                        HStack(spacing: 10) {
                            Button {
                                pulseToken += 1
                                model.previewHaptic()
                            } label: {
                                Label("Test haptic", systemImage: "hand.point.up.left.fill")
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

            HStack(alignment: .top, spacing: 12) {
                MetricTile(
                    title: "Haptic ticks",
                    value: "\(model.input.hapticCount)",
                    detail: "This session",
                    tint: Theme.teal,
                    systemImage: "hand.point.up.left.fill"
                )
                MetricTile(
                    title: "Pattern",
                    value: model.settings.hapticPattern.title,
                    detail: model.settings.hapticPattern.detail,
                    tint: Theme.teal,
                    systemImage: "waveform.path"
                )
                MetricTile(
                    title: "Independent",
                    value: model.settings.hapticsEnabled ? "Enabled" : "Off",
                    detail: "Audio can be on or off independently",
                    tint: Theme.teal,
                    systemImage: "switch.2"
                )
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What the public API can and cannot do")
                        .font(.system(.headline, design: .rounded))
                    boundary("Available", "Three predefined patterns (generic, alignment, level change) through NSHapticFeedbackManager.")
                    boundary("Not available", "No numeric intensity, no arbitrary actuator waveform, and no capability-query method in the public API.")
                    boundary("Not shipped", "TactileMac does not call private MultitouchSupport framework symbols. Research on that approach is documented, but it is not in the production path.")
                    boundary("Physical verification", "The app can invoke the API; software cannot prove that a person felt the tick. Use the test button and judge the physical result.")
                }
            }

            if !model.trackpad.detected {
                InfoBanner(
                    title: "No haptic trackpad was detected through IORegistry",
                    message: "Keyboard and trackpad audio continue to work. External trackpads and Force Touch support vary by hardware.",
                    systemImage: "exclamationmark.triangle",
                    tint: Theme.amber
                )
            }

            Card {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Theme.teal)
                        Text("Why there is no intensity slider")
                            .font(.callout.weight(.semibold))
                    }
                    Text("AppKit exposes pattern choice and a performance-time hint, not actuator strength. Adding a strength slider would misrepresent a public API that does not offer one. The pattern picker is the honest control.")
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
                .frame(width: 108, alignment: .leading)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct HapticsSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Card {
                VStack(alignment: .leading, spacing: 13) {
                    SectionLabel(text: "Physical feedback")
                    ToggleRow(title: "Haptics", subtitle: "Independent from all audio", isOn: model.binding(\.hapticsEnabled), tint: Theme.teal)
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pattern").font(.callout)
                        Picker("Pattern", selection: model.binding(\.hapticPattern)) {
                            ForEach(HapticPatternName.allCases) { pattern in
                                Text("\(pattern.title) — \(pattern.detail)").tag(pattern)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    Text("These are AppKit presets. They are not adjustable-strength actuator waveforms.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Triggers")
                    ToggleRow(title: "Keyboard ticks", subtitle: "On key down and modifier presses", isOn: model.binding(\.hapticOnKeyboard), tint: Theme.teal)
                    ToggleRow(title: "Trackpad clicks", subtitle: "Button-down events", isOn: model.binding(\.hapticOnTrackpadClicks), tint: Theme.teal)
                    ToggleRow(title: "Scroll ticks", subtitle: "Rate limited separately from audio", isOn: model.binding(\.hapticOnScroll), tint: Theme.teal)
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
                    KeyValueRow(label: "Built-in", value: model.trackpad.embedded ? "Yes" : "No / unknown")
                    KeyValueRow(label: "Product", value: model.trackpad.productName ?? "Unknown")
                    Button {
                        model.previewHaptic()
                    } label: {
                        Label("Test current pattern", systemImage: "hand.point.up.left.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.teal, compact: true))
                    .accessibilityIdentifier("haptics.settings.test")
                    Text("Physical feel requires an in-person test. The app cannot detect whether you felt it.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
