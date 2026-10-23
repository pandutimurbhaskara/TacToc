import SwiftUI

struct PermissionsPage: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Permissions & Hardware",
                subtitle: "Real status from the current process. Nothing is requested until you ask for it.",
                badge: model.permissions.inputMonitoring == .granted ? "Input granted" : "Action needed",
                badgeColor: model.permissions.inputMonitoring == .granted ? Theme.teal : Theme.amber,
                trailing: AnyView(
                    Button("Refresh") { model.refreshHardware() }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                )
            )

            if let error = model.permissions.tapError {
                InfoBanner(
                    title: "Event tap status",
                    message: error,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: Theme.coral,
                    actionTitle: "Retry tap",
                    action: { model.retryInputTap() },
                    secondaryTitle: "Open settings",
                    secondaryAction: { model.openInputMonitoringSettings() }
                )
            }

            permissionCard(
                title: "Input Monitoring",
                status: model.permissions.inputMonitoring.title,
                color: model.permissions.inputMonitoring == .granted ? Theme.teal : Theme.amber,
                systemImage: "lock.shield",
                explanation: "Required for a listen-only CGEventTap. It lets TactileMac observe global key-down, key-up, modifier, mouse-button, and scroll events. The tap cannot modify or block events.",
                detail: model.permissions.inputMonitoring == .granted
                    ? "Event tap is \(model.permissions.tapRunning ? "running" : "stopped"). Granting access may require relaunching the app on some macOS versions."
                    : "Without this permission, keyboard and trackpad feedback stay silent. Audio preview buttons still work."
            ) {
                HStack(spacing: 8) {
                    Button("Request access") { model.requestInputMonitoring() }
                        .buttonStyle(PrimaryButtonStyle(compact: true))
                        .accessibilityIdentifier("permissions.requestInput")
                    Button("Open System Settings") { model.openInputMonitoringSettings() }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                    Button("Retry event tap") { model.retryInputTap() }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }

            permissionCard(
                title: "Accessibility",
                status: model.permissions.accessibilityTrusted ? "Granted" : "Not granted",
                color: Theme.purple,
                systemImage: "accessibility",
                explanation: "TactileMac does not use the Accessibility API. It does not inspect UI elements, window contents, or control labels. For that reason it does not request Accessibility access.",
                detail: "This row reports the system value for transparency only. Keyboard and trackpad audio do not depend on it."
            ) {
                Button("Open Accessibility Settings") { model.openAccessibilitySettings() }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
            }

            permissionCard(
                title: "Secure Event Input",
                status: model.permissions.secureInputActive ? "Active" : "Inactive",
                color: model.permissions.secureInputActive ? Theme.amber : Theme.teal,
                systemImage: "exclamationmark.shield",
                explanation: "macOS enables Secure Event Input for password fields and other protected contexts. While it is active, keystrokes are hidden from all event taps; TactileMac never attempts to bypass this.",
                detail: model.permissions.secureInputActive
                    ? "Keyboard feedback is paused until the secure context closes."
                    : "No secure input context is currently detected. This status is polled, so it can lag a protected prompt by a moment."
            ) {
                EmptyView()
            }

            HStack(alignment: .top, spacing: 12) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            IconTile(systemImage: "hand.point.up.left.fill", tint: Theme.teal, size: 34)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Trackpad & haptics")
                                    .font(.system(.headline, design: .rounded))
                                Text(model.trackpad.actuationReported ? "Actuation reported" : (model.trackpad.detected ? "Detected" : "Not detected"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(model.trackpad.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let product = model.trackpad.productName {
                            KeyValueRow(label: "Product", value: product)
                        }
                        Button("Test haptic preset") { model.previewHaptic() }
                            .buttonStyle(SecondaryButtonStyle(tint: Theme.teal, compact: true))
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            IconTile(systemImage: "speaker.wave.2.fill", tint: Theme.purple, size: 34)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Audio output")
                                    .font(.system(.headline, design: .rounded))
                                Text(model.audioInfo.isReady ? "Ready" : "Not ready")
                                    .font(.caption)
                                    .foregroundStyle(model.audioInfo.isReady ? Theme.teal : Theme.amber)
                            }
                        }
                        KeyValueRow(label: "Device", value: model.audioInfo.deviceName)
                        KeyValueRow(label: "Rate", value: model.audioInfo.sampleRate > 0 ? "\(Int(model.audioInfo.sampleRate)) Hz" : "Unknown")
                        KeyValueRow(label: "Buffer", value: "\(model.audioInfo.hardwareBufferFrames) frames")
                        if let error = model.engineError {
                            CopyableErrorBox(text: error)
                        }
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 9) {
                    Text("What happens if permission is revoked?")
                        .font(.system(.headline, design: .rounded))
                    Text("The event tap stops. The audio engine and sound pack manager remain alive, so previews still work and settings are preserved. When Input Monitoring is granted again, TactileMac retries the tap without relaunching when macOS permits it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            model.markPermissionGuidanceSeen()
            model.refreshHardware()
        }
    }

    private func permissionCard<Actions: View>(
        title: String,
        status: String,
        color: Color,
        systemImage: String,
        explanation: String,
        detail: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 10) {
                    IconTile(systemImage: systemImage, tint: color, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(.headline, design: .rounded))
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(color)
                    }
                    Spacer()
                    Circle().fill(color).frame(width: 8, height: 8)
                }
                Text(explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                actions()
            }
        }
    }
}

struct PermissionsSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Input Monitoring steps")
                    step(1, "Open System Settings → Privacy & Security → Input Monitoring.")
                    step(2, "Enable TactileMac. macOS may ask you to relaunch the app.")
                    step(3, "Return here and press Retry event tap. The status above must read Granted.")
                    step(4, "If the row is enabled but the tap still fails, remove and re-add TactileMac in System Settings.")
                    HStack(spacing: 8) {
                        Button("Open System Settings") { model.openInputMonitoringSettings() }
                            .buttonStyle(PrimaryButtonStyle(compact: true))
                        Button("Retry tap") { model.retryInputTap() }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 11) {
                    SectionLabel(text: "Privacy by design")
                    privacyLine("No typed characters are read or stored.")
                    privacyLine("No clipboard, screen contents, or accessibility tree is inspected.")
                    privacyLine("No telemetry, analytics, or network requests. The app has no network client.")
                    privacyLine("Key identity is discarded after choosing a sound category.")
                    privacyLine("Secure Event Input is respected, never bypassed.")
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Current status")
                    KeyValueRow(label: "Input", value: model.permissions.inputMonitoring.title, color: model.permissions.inputMonitoring == .granted ? Theme.teal : Theme.amber)
                    KeyValueRow(label: "Tap", value: model.permissions.tapRunning ? "Running" : "Stopped")
                    KeyValueRow(label: "Secure input", value: model.permissions.secureInputActive ? "Active" : "Inactive")
                    KeyValueRow(label: "Accessibility", value: model.permissions.accessibilityTrusted ? "Granted (unused)" : "Not granted (unused)")
                    if let error = model.permissions.tapError {
                        CopyableErrorBox(text: error)
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Data location")
                    Text(model.paths.applicationSupport.path)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Button("Open Application Support") { model.openDataFolder() }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(number)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(Theme.purple, in: Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func privacyLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.teal)
                .padding(.top, 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
