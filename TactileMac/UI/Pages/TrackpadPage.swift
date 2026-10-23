import SwiftUI

struct TrackpadPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var token = 0
    @State private var direction = "click"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Trackpad Sounds",
                subtitle: "Clicks and precise scrolling with independent volume, pack, throttle, and haptic options.",
                badge: "Independent",
                badgeColor: Theme.purple
            )

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Interaction surface")
                                .font(.system(.headline, design: .rounded))
                            Text("Simulated preview — no raw touch, force, or contact data is read.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusPill(text: "Simulated preview", color: Theme.purple, systemImage: "sparkles")
                    }

                    TrackpadView(pulseToken: token, pulseDirection: direction)
                        .padding(.vertical, 4)

                    HStack(spacing: 8) {
                        Button("Left click") { previewClick(.left) }
                            .buttonStyle(PrimaryButtonStyle(compact: true))
                        Button("Right click") { previewClick(.right) }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                        Button("Scroll ↑") { previewScroll("up") }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                        Button("Scroll ↓") { previewScroll("down") }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                        Spacer()
                        Text(model.selectedTrackpadPack?.name ?? "No pack")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                MetricTile(title: "Pointer events", value: "\(model.input.trackpadEventCount)", detail: "Clicks and scrolls observed", tint: Theme.purple, systemImage: "cursorarrow")
                MetricTile(
                    title: "Scroll throttle",
                    value: "\(Int(model.settings.scrollMinimumIntervalMs)) ms",
                    detail: "Minimum gap between scroll sounds",
                    tint: Theme.teal,
                    systemImage: "timer"
                )
                MetricTile(
                    title: "Click debounce",
                    value: "\(Int(model.settings.clickDebounceMs)) ms",
                    detail: "Suppresses duplicate button downs",
                    tint: Theme.purple,
                    systemImage: "cursorarrow.click"
                )
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Verified detection boundaries")
                        .font(.system(.headline, design: .rounded))
                    limitRow("Global button down/up", "Left, right, and middle/other buttons are observed. Auxiliary buttons are ignored for audio.")
                    limitRow("Precise scrolling", "Trackpad and Magic Mouse scroll events carry precise deltas. Mouse wheels are excluded when ‘precise only’ is on.")
                    limitRow("Momentum", "Momentum scrolling is filtered out by default; it can be enabled below.")
                    limitRow("Trackpad identity", "Public event APIs do not reliably say whether a click came from the built-in trackpad. Click sounds may play for mouse clicks too.")
                    limitRow("Touches and force", "Contact count, finger position, pressure, and Force Touch stages are not available through the APIs used here.")
                }
            }
        }
    }

    private func limitRow(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.teal)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func previewClick(_ button: MouseButtonName) {
        direction = button == .right ? "right" : "click"
        token += 1
        model.previewTrackpadClick(button)
    }

    private func previewScroll(_ value: String) {
        direction = value
        token += 1
        model.previewTrackpadScroll(value)
    }
}

struct TrackpadSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Card {
                VStack(alignment: .leading, spacing: 13) {
                    SectionLabel(text: "Trackpad feedback")
                    ToggleRow(title: "Trackpad sounds", subtitle: "Clicks and scrolling", isOn: model.binding(\.trackpadEnabled))
                    Divider()
                    SliderRow(
                        title: "Volume",
                        value: model.binding(\.trackpadVolume),
                        range: 0...1,
                        display: "\(Int(model.settings.trackpadVolume * 100))%"
                    )
                    Divider()
                    ToggleRow(title: "Click sounds", subtitle: "Button-down feedback", isOn: model.binding(\.trackpadClicksEnabled))
                    ToggleRow(title: "Scroll sounds", subtitle: "Throttled by the interval below", isOn: model.binding(\.trackpadScrollEnabled))
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Filtering")
                    ToggleRow(title: "Precise scrolling only", subtitle: "Ignore discrete mouse-wheel events", isOn: model.binding(\.preciseScrollOnly))
                    ToggleRow(title: "Include momentum", subtitle: "Play while the scroll coasts after your fingers lift", isOn: model.binding(\.includeMomentumScroll))
                    Divider()
                    SliderRow(
                        title: "Scroll interval",
                        value: model.binding(\.scrollMinimumIntervalMs),
                        range: 16...160,
                        display: "\(Int(model.settings.scrollMinimumIntervalMs)) ms"
                    )
                    SliderRow(
                        title: "Click debounce",
                        value: model.binding(\.clickDebounceMs),
                        range: 10...200,
                        display: "\(Int(model.settings.clickDebounceMs)) ms"
                    )
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Sound pack")
                    Picker("Trackpad pack", selection: model.binding(\.trackpadPackID)) {
                        ForEach(model.trackpadPackOptions) { pack in
                            Text(pack.name).tag(pack.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    if let pack = model.selectedTrackpadPack {
                        KeyValueRow(label: "Events", value: "\(pack.trackpadEventCount)")
                        KeyValueRow(label: "Source", value: pack.sourceFormat.shortTitle)
                    }
                    if let error = model.packLoadErrors[model.settings.trackpadPackID] {
                        CopyableErrorBox(text: error)
                    }
                    Button("Manage sound packs") { model.selectedPage = .soundPacks }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Test")
                    Button {
                        model.previewTrackpadClick(.left)
                    } label: {
                        Label("Left click", systemImage: "cursorarrow.click").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                    HStack(spacing: 8) {
                        Button("Scroll ↑") { model.previewTrackpadScroll("up") }
                            .buttonStyle(CompactButtonStyle())
                        Button("Scroll ↓") { model.previewTrackpadScroll("down") }
                            .buttonStyle(CompactButtonStyle())
                    }
                }
            }
        }
    }
}
