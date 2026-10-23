import SwiftUI

struct OverviewPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var keyboardToken = 0
    @State private var highlightedKey: String?
    @State private var trackpadToken = 0
    @State private var scrollDirection = "click"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Overview",
                subtitle: "Independent keyboard, trackpad, and haptic feedback with one shared coordinator.",
                badge: model.permissions.tapRunning ? "Live" : (model.permissions.inputMonitoring == .granted ? "Ready" : "Permission needed"),
                badgeColor: model.permissions.tapRunning ? Theme.teal : Theme.amber,
                trailing: AnyView(
                    Button("Refresh") { model.refreshHardware() }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                )
            )

            if model.permissions.inputMonitoring != .granted && model.needsInputMonitoring {
                InfoBanner(
                    title: "Keyboard and trackpad monitoring needs Input Monitoring",
                    message: "TactileMac uses a listen-only event tap. It never stores typed text. Grant access when you are ready, then return here.",
                    systemImage: "lock.shield",
                    tint: Theme.amber,
                    actionTitle: "Review permissions",
                    action: { model.selectedPage = .permissions },
                    secondaryTitle: "Request access",
                    secondaryAction: { model.requestInputMonitoring() }
                )
            }

            HStack(spacing: 12) {
                featureCard(
                    title: "Keyboard",
                    subtitle: model.selectedKeyboardPack?.name ?? "No pack selected",
                    detail: "\(Int(model.settings.keyboardVolume * 100))% volume · \(model.settings.playKeyUpSounds ? "press + release" : "press only")",
                    systemImage: "keyboard",
                    tint: Theme.purple,
                    enabled: model.binding(\.keyboardEnabled),
                    page: .keyboard
                )
                featureCard(
                    title: "Trackpad",
                    subtitle: "Clicks and precise scrolling",
                    detail: "\(Int(model.settings.trackpadVolume * 100))% volume · independent pack",
                    systemImage: "hand.tap",
                    tint: Theme.purple,
                    enabled: model.binding(\.trackpadEnabled),
                    page: .trackpad
                )
                featureCard(
                    title: "Haptics",
                    subtitle: model.trackpad.actuationReported ? "Force Touch hardware reported" : "Public AppKit API",
                    detail: "\(model.settings.hapticPattern.title) preset · no intensity API",
                    systemImage: "hand.point.up.left.fill",
                    tint: Theme.teal,
                    enabled: model.binding(\.hapticsEnabled),
                    page: .haptics
                )
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keyboard preview")
                                .font(.system(.headline, design: .rounded))
                            Text("A simulated preview — the app does not display or store typed characters.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusPill(text: "Simulated", color: Theme.purple, systemImage: "sparkles")
                    }

                    KeyboardView(highlightedKey: highlightedKey, highlightToken: keyboardToken)
                        .padding(.vertical, 2)

                    HStack(spacing: 10) {
                        Button {
                            playKeyboard(press: true)
                        } label: {
                            Label("Preview press", systemImage: "play.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle(compact: true))
                        .accessibilityIdentifier("overview.previewPress")

                        Button {
                            playKeyboard(press: false)
                        } label: {
                            Label("Preview release", systemImage: "play.circle")
                        }
                        .buttonStyle(SecondaryButtonStyle(compact: true))

                        Spacer()
                        Text("Using \(model.selectedKeyboardPack?.name ?? "no pack")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(alignment: .top, spacing: 14) {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Trackpad preview")
                                    .font(.system(.headline, design: .rounded))
                                Text("Click and scroll events that public APIs can observe.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusPill(text: "Simulated", color: Theme.purple, systemImage: "sparkles")
                        }

                        TrackpadView(pulseToken: trackpadToken, pulseDirection: scrollDirection)
                            .padding(.vertical, 4)

                        HStack(spacing: 7) {
                            Button("Left click") { playTrackpad(button: .left) }
                                .buttonStyle(CompactButtonStyle())
                            Button("Right click") { playTrackpad(button: .right) }
                                .buttonStyle(CompactButtonStyle())
                            Button("Scroll ↑") { playScroll("up") }
                                .buttonStyle(CompactButtonStyle())
                            Button("Scroll ↓") { playScroll("down") }
                                .buttonStyle(CompactButtonStyle())
                        }
                        .accessibilityIdentifier("overview.trackpadPreviews")

                        Text("Clicks may come from a mouse: macOS does not expose a reliable public trackpad-only click flag.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("System status")
                            .font(.system(.headline, design: .rounded))
                        statusRow("Input Monitoring", model.permissions.inputMonitoring.title, good: model.permissions.inputMonitoring == .granted)
                        statusRow("Secure Event Input", model.permissions.secureInputActive ? "Active" : "Inactive", good: !model.permissions.secureInputActive)
                        statusRow("Audio output", model.audioInfo.isReady ? "\(model.audioInfo.deviceName) · \(Int(model.audioInfo.sampleRate)) Hz" : "Unavailable", good: model.audioInfo.isReady)
                        statusRow("Trackpad", model.trackpad.actuationReported ? "Actuation reported" : (model.trackpad.detected ? "Detected" : "Not found"), good: model.trackpad.detected)
                        Divider()
                        Button("Open Permissions & Hardware") { model.selectedPage = .permissions }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                    }
                }
                .frame(maxWidth: 330)
            }

            Card {
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Text("This session")
                            .font(.system(.headline, design: .rounded))
                        Spacer()
                        Text("Counts are local and reset on relaunch")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                        MetricTile(title: "Key events", value: "\(model.input.keyboardEventCount)", tint: Theme.purple, systemImage: "keyboard")
                        MetricTile(title: "Pointer events", value: "\(model.input.trackpadEventCount)", tint: Theme.purple, systemImage: "cursorarrow")
                        MetricTile(title: "Sounds played", value: "\(model.input.soundCount)", tint: Theme.teal, systemImage: "speaker.wave.2.fill")
                        MetricTile(title: "Haptic ticks", value: "\(model.input.hapticCount)", tint: Theme.teal, systemImage: "hand.point.up.left.fill")
                    }
                }
            }
        }
    }

    private func featureCard(
        title: String,
        subtitle: String,
        detail: String,
        systemImage: String,
        tint: Color,
        enabled: Binding<Bool>,
        page: AppPage
    ) -> some View {
        Card(padding: 15) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    IconTile(systemImage: systemImage, tint: tint, size: 36)
                    Spacer()
                    Toggle("", isOn: enabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(tint)
                        .accessibilityIdentifier("overview.\(title.lowercased()).enabled")
                }
                Text(title)
                    .font(.system(.headline, design: .rounded))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Button("Open \(title)") { model.selectedPage = page }
                    .buttonStyle(CompactButtonStyle(tint: tint))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statusRow(_ label: String, _ value: String, good: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(good ? Theme.teal : Theme.amber)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func playKeyboard(press: Bool) {
        model.previewKeyboard(press: press)
        let key = press ? "g" : "g"
        highlightedKey = key
        keyboardToken += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if highlightedKey == key { highlightedKey = nil }
        }
    }

    private func playTrackpad(button: MouseButtonName) {
        scrollDirection = button == .right ? "right" : "click"
        trackpadToken += 1
        model.previewTrackpadClick(button)
    }

    private func playScroll(_ direction: String) {
        scrollDirection = direction
        trackpadToken += 1
        model.previewTrackpadScroll(direction)
    }
}

struct OverviewSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Card {
                VStack(alignment: .leading, spacing: 13) {
                    SectionLabel(text: "Quick controls")
                    ToggleRow(title: "Keyboard sounds", subtitle: "Mechanical feedback for key events", isOn: model.binding(\.keyboardEnabled))
                    Divider()
                    SliderRow(
                        title: "Keyboard volume",
                        value: model.binding(\.keyboardVolume),
                        range: 0...1,
                        display: "\(Int(model.settings.keyboardVolume * 100))%"
                    )
                    Divider()
                    ToggleRow(title: "Trackpad sounds", subtitle: "Clicks and precise scrolling", isOn: model.binding(\.trackpadEnabled))
                    Divider()
                    SliderRow(
                        title: "Trackpad volume",
                        value: model.binding(\.trackpadVolume),
                        range: 0...1,
                        display: "\(Int(model.settings.trackpadVolume * 100))%"
                    )
                    Divider()
                    ToggleRow(title: "Physical haptics", subtitle: "Public AppKit presets only", isOn: model.binding(\.hapticsEnabled), tint: Theme.teal)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Active profiles")
                    profileRow("Keyboard", model.selectedKeyboardPack?.name ?? "None", color: Theme.purple)
                    profileRow("Trackpad", model.selectedTrackpadPack?.name ?? "None", color: Theme.purple)
                    Button("Choose profiles") { model.selectedPage = .profiles }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Permission")
                    HStack(spacing: 7) {
                        Circle()
                            .fill(model.permissions.inputMonitoring == .granted ? Theme.teal : Theme.amber)
                            .frame(width: 7, height: 7)
                        Text(model.permissions.inputMonitoring.title)
                            .font(.callout.weight(.semibold))
                    }
                    Text(model.permissions.inputMonitoring == .granted
                         ? "Global key and pointer events are available to the listen-only tap."
                         : "Keyboard and trackpad audio stay silent until Input Monitoring is granted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.permissions.inputMonitoring != .granted {
                        Button("Review permissions") { model.selectedPage = .permissions }
                            .buttonStyle(PrimaryButtonStyle(compact: true))
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Preview")
                    Button {
                        model.previewKeyboard(press: true)
                    } label: {
                        Label("Play a key sound", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                    Button {
                        model.previewHaptic()
                    } label: {
                        Label("Test haptic preset", systemImage: "hand.point.up.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(tint: Theme.teal, compact: true))
                }
            }
        }
    }

    private func profileRow(_ label: String, _ value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.callout.weight(.medium)).foregroundStyle(color)
        }
    }
}
