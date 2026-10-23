import SwiftUI

struct KeyboardPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var highlightedKey: String?
    @State private var token = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Keyboard Sounds",
                subtitle: "Press and release feedback from a listen-only global event tap.",
                badge: model.permissions.inputMonitoring == .granted ? "Input available" : "Permission needed",
                badgeColor: model.permissions.inputMonitoring == .granted ? Theme.teal : Theme.amber
            )

            if model.permissions.inputMonitoring != .granted && model.settings.keyboardEnabled {
                InfoBanner(
                    title: "Keyboard monitoring is waiting for permission",
                    message: "macOS requires Input Monitoring for a listen-only event tap. No typed characters are read, stored, or transmitted.",
                    systemImage: "lock.shield",
                    tint: Theme.amber,
                    actionTitle: "Review permissions",
                    action: { model.selectedPage = .permissions }
                )
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keyboard surface")
                                .font(.system(.headline, design: .rounded))
                            Text("Live key identity is deliberately not shown. The visualization is decorative.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusPill(text: "Simulated preview", color: Theme.purple, systemImage: "sparkles")
                    }

                    KeyboardView(highlightedKey: highlightedKey, highlightToken: token)
                        .padding(.vertical, 4)

                    HStack(spacing: 10) {
                        Button {
                            preview(press: true)
                        } label: {
                            Label("Preview press", systemImage: "play.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle(compact: true))
                        .accessibilityIdentifier("keyboard.previewPress")

                        Button {
                            preview(press: false)
                        } label: {
                            Label("Preview release", systemImage: "play.circle")
                        }
                        .buttonStyle(SecondaryButtonStyle(compact: true))

                        Spacer()
                        Text(model.selectedKeyboardPack?.name ?? "No pack")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                MetricTile(title: "Key events", value: "\(model.input.keyboardEventCount)", detail: "This session", tint: Theme.purple, systemImage: "keyboard")
                MetricTile(
                    title: "Engine latency",
                    value: latencyText,
                    detail: "Event → first mixed buffer",
                    tint: Theme.teal,
                    systemImage: "speedometer"
                )
                MetricTile(
                    title: "Audio buffer",
                    value: "\(model.settings.audioBufferFrames) fr",
                    detail: "\(Int(model.audioInfo.sampleRate)) Hz output",
                    tint: Theme.purple,
                    systemImage: "waveform"
                )
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What TactileMac observes")
                        .font(.system(.headline, design: .rounded))
                    captureRow("Hardware key code", "Used only to choose a sound category; discarded immediately.")
                    captureRow("Key down / key up", "Routed through the shared coordinator with duplicate suppression.")
                    captureRow("Key repeats", model.settings.playKeyRepeatSounds ? "Played because the optional repeat setting is on." : "Suppressed by default.")
                    captureRow("Typed characters", "Never read, never stored, never sent over a network.")
                    Divider()
                    HStack(spacing: 7) {
                        Image(systemName: model.permissions.secureInputActive ? "exclamationmark.shield.fill" : "checkmark.shield")
                            .foregroundStyle(model.permissions.secureInputActive ? Theme.amber : Theme.teal)
                        Text(model.permissions.secureInputActive
                             ? "Secure Event Input is active. macOS hides keystrokes from every app, so feedback pauses."
                             : "Secure Event Input is inactive. TactileMac still discards key identity after routing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var latencyText: String {
        if let average = model.input.averageEngineLatencyMs {
            return String(format: "%.1f ms", average)
        }
        return "—"
    }

    private func captureRow(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Circle().fill(Theme.purple.opacity(0.6)).frame(width: 5, height: 5).padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func preview(press: Bool) {
        model.previewKeyboard(press: press)
        highlightedKey = "g"
        token += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if highlightedKey == "g" { highlightedKey = nil }
        }
    }
}

struct KeyboardSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Card {
                VStack(alignment: .leading, spacing: 13) {
                    SectionLabel(text: "Keyboard feedback")
                    ToggleRow(title: "Keyboard sounds", subtitle: "Global press and release feedback", isOn: model.binding(\.keyboardEnabled))
                    Divider()
                    SliderRow(
                        title: "Volume",
                        value: model.binding(\.keyboardVolume),
                        range: 0...1,
                        display: "\(Int(model.settings.keyboardVolume * 100))%"
                    )
                    Divider()
                    ToggleRow(title: "Play release sounds", subtitle: "Adds a lighter key-up sample", isOn: model.binding(\.playKeyUpSounds))
                    ToggleRow(title: "Play modifier sounds", subtitle: "Command, Option, Control, Shift, Caps Lock, Fn", isOn: model.binding(\.playModifierSounds))
                    ToggleRow(title: "Play key-repeat sounds", subtitle: "By default, held-key repeats stay silent", isOn: model.binding(\.playKeyRepeatSounds))
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Sound pack")
                    Picker("Keyboard pack", selection: model.binding(\.keyboardPackID)) {
                        ForEach(model.keyboardPackOptions) { pack in
                            Text(pack.name).tag(pack.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    if let pack = model.selectedKeyboardPack {
                        KeyValueRow(label: "Events", value: "\(pack.keyboardEventCount)")
                        KeyValueRow(label: "Source", value: pack.sourceFormat.shortTitle)
                    }
                    if let error = model.packLoadErrors[model.settings.keyboardPackID] {
                        CopyableErrorBox(text: error)
                    }
                    Button("Manage sound packs") { model.selectedPage = .soundPacks }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Variation")
                    SliderRow(
                        title: "Pitch variation",
                        subtitle: "Per-keystroke random tuning, in semitones",
                        value: model.binding(\.pitchVariation),
                        range: 0...1,
                        display: String(format: "±%.2f st", model.settings.pitchVariation)
                    )
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Test")
                    Button {
                        model.previewKeyboard(press: true)
                    } label: {
                        Label("Play key down", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                    Button {
                        model.previewKeyboard(press: false)
                    } label: {
                        Label("Play key up", systemImage: "play.circle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    Divider()
                    HStack(spacing: 7) {
                        Circle()
                            .fill(model.permissions.inputMonitoring == .granted ? Theme.teal : Theme.amber)
                            .frame(width: 6, height: 6)
                        Text(model.permissions.inputMonitoring == .granted ? "Input Monitoring granted" : "Input Monitoring not granted")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if model.permissions.inputMonitoring != .granted {
                        Button("Open permissions") { model.selectedPage = .permissions }
                            .buttonStyle(CompactButtonStyle(tint: Theme.amber))
                    }
                }
            }
        }
    }
}
