import SwiftUI

struct AdvancedPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Advanced",
                subtitle: "Engine timing, output details, and maintenance. No telemetry or network access.",
                badge: "Local only",
                badgeColor: Theme.teal
            )

            HStack(alignment: .top, spacing: 12) {
                MetricTile(
                    title: "Event → mix (avg)",
                    value: averageLatency,
                    detail: "Measured inside the app",
                    tint: Theme.teal,
                    systemImage: "speedometer"
                )
                MetricTile(
                    title: "Event → mix (last)",
                    value: lastLatency,
                    detail: "One recent sound",
                    tint: Theme.purple,
                    systemImage: "clock.arrow.circlepath"
                )
                MetricTile(
                    title: "Output latency",
                    value: String(format: "%.1f ms", model.audioInfo.computedOutputLatencyMs),
                    detail: "CoreAudio-reported components",
                    tint: Theme.purple,
                    systemImage: "waveform"
                )
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Audio output")
                        .font(.system(.headline, design: .rounded))
                    KeyValueRow(label: "Device", value: model.audioInfo.deviceName)
                    KeyValueRow(label: "Nominal rate", value: model.audioInfo.sampleRate > 0 ? "\(Int(model.audioInfo.sampleRate)) Hz" : "Unknown")
                    KeyValueRow(label: "Hardware buffer", value: model.audioInfo.hardwareBufferFrames > 0 ? "\(model.audioInfo.hardwareBufferFrames) frames" : "Unknown")
                    KeyValueRow(label: "Device latency", value: String(format: "%.2f ms", model.audioInfo.deviceLatencyMs))
                    KeyValueRow(label: "Safety offset", value: String(format: "%.2f ms", model.audioInfo.safetyOffsetMs))
                    KeyValueRow(label: "Engine buffer", value: "\(model.settings.audioBufferFrames) frames")
                    KeyValueRow(label: "Engine state", value: model.audioInfo.isReady ? "Running" : "Not running", color: model.audioInfo.isReady ? Theme.teal : Theme.amber)
                    if let error = model.engineError {
                        CopyableErrorBox(text: error)
                    }
                    Button("Refresh hardware details") { model.refreshHardware() }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 11) {
                    Text("How latency is reported")
                        .font(.system(.headline, design: .rounded))
                    Text("Measured: the coordinator timestamps a chosen sound when it is enqueued, and the audio callback records when that voice is first mixed into a buffer. This is a real in-app measurement, not an estimate, but it excludes the DAC, amplifier, drivers, and room.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Reported: CoreAudio exposes the hardware buffer size, device latency, and safety offset. Those are driver-reported values, summed here; they are not measured acoustically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("No end-to-end acoustic latency measurement was performed in this build.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.amber)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Engine behavior")
                        .font(.system(.headline, design: .rounded))
                    behavior("Preloading", "Audio files are decoded to interleaved stereo Float32 before playback. Event callbacks never open or decode files.")
                    behavior("Voices", "Up to 32 overlapping voices. The oldest voice is evicted when the pool is full.")
                    behavior("Clipping", "A soft tanh limiter prevents hard clipping when many voices overlap.")
                    behavior("Device changes", "A CoreAudio listener rebuilds the queue when the default output changes; wake from sleep triggers the same recovery.")
                    behavior("Idle", "The queue stays open while monitoring is enabled and renders silence. Rendering silence is cheap but not zero-cost.")
                    behavior("Secure input", "Events are dropped while Secure Event Input is active; macOS usually hides them entirely.")
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Maintenance")
                        .font(.system(.headline, design: .rounded))
                    HStack(spacing: 9) {
                        Button { model.openDataFolder() } label: {
                            Label("Open Application Support", systemImage: "folder")
                        }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                        Button { model.copyDiagnostics() } label: {
                            Label("Copy diagnostics", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                        Button { model.rescanPacks() } label: {
                            Label("Rescan packs", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset all settings").font(.callout)
                            Text("Restores defaults, including the Thock profile and 65% keyboard volume.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset…", role: .destructive) { confirmReset = true }
                            .buttonStyle(SecondaryButtonStyle(tint: Theme.coral, compact: true))
                    }
                }
            }
        }
        .alert("Reset all settings?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { model.resetSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Imported sound packs are not deleted. This only resets preferences.")
        }
    }

    private var averageLatency: String {
        if let value = model.input.averageEngineLatencyMs { return String(format: "%.1f ms", value) }
        return "—"
    }

    private var lastLatency: String {
        if let value = model.input.lastEngineLatencyMs { return String(format: "%.1f ms", value) }
        return "—"
    }

    private func behavior(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.purple)
                .frame(width: 94, alignment: .leading)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AdvancedSettings: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 14) {
            Card {
                VStack(alignment: .leading, spacing: 13) {
                    SectionLabel(text: "Performance")
                    PickerRow(title: "Audio buffer", selection: model.binding(\.audioBufferFrames)) {
                        Text("128 frames").tag(128)
                        Text("256 frames").tag(256)
                        Text("512 frames").tag(512)
                        Text("1024 frames").tag(1024)
                    }
                    Text("Smaller buffers reduce engine scheduling delay but ask more of the CPU and output device. The output device may impose a larger hardware buffer regardless.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    SliderRow(
                        title: "Pitch variation",
                        subtitle: "Global random tuning for keyboard and trackpad sounds",
                        value: model.binding(\.pitchVariation),
                        range: 0...1,
                        display: String(format: "±%.2f st", model.settings.pitchVariation)
                    )
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 13) {
                    SectionLabel(text: "Interface")
                    ToggleRow(title: "Menu bar shortcut", subtitle: "Convenience only; the main window remains primary", isOn: model.binding(\.showMenuBarExtra))
                    Text("If the menu bar extra is hidden, re-enable it here. Closing the main window does not stop feedback while monitoring is active.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Diagnostics")
                    KeyValueRow(label: "Engine", value: model.audioInfo.isReady ? "Ready" : "Not ready", color: model.audioInfo.isReady ? Theme.teal : Theme.amber)
                    KeyValueRow(label: "Tap", value: model.permissions.tapRunning ? "Running" : "Stopped")
                    KeyValueRow(label: "Secure input", value: model.permissions.secureInputActive ? "Active" : "Inactive", color: model.permissions.secureInputActive ? Theme.amber : Theme.teal)
                    if let error = model.permissions.tapError {
                        CopyableErrorBox(text: error)
                    }
                    Button { model.copyDiagnostics() } label: {
                        Label("Copy diagnostics", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 9) {
                    SectionLabel(text: "Reset")
                    Text("Restores all preferences to defaults. Imported packs and their files are preserved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Reset settings…") { confirmReset = true }
                        .buttonStyle(SecondaryButtonStyle(tint: Theme.coral, compact: true))
                }
            }
        }
        .alert("Reset all settings?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { model.resetSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Imported sound packs are not deleted.")
        }
    }
}
