import AppKit
import SwiftUI

struct AboutPage: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "License & About",
                subtitle: "What this build includes, what it does not, and how it handles your input.",
                badge: "v\(model.appVersion)",
                badgeColor: Theme.purple
            )

            Card {
                HStack(alignment: .center, spacing: 18) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("TactileMac")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("Native macOS keyboard sounds, trackpad feedback, public haptics, and validated sound packs.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            StatusPill(text: "SwiftUI", color: Theme.purple)
                            StatusPill(text: "AudioQueue", color: Theme.purple)
                            StatusPill(text: "Material haptics", color: Theme.teal)
                            StatusPill(text: "No telemetry", color: Theme.teal)
                        }
                        .padding(.top, 2)
                    }
                    Spacer()
                }
            }

            HStack(alignment: .top, spacing: 12) {
                Card {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Source license")
                            .font(.system(.headline, design: .rounded))
                        Text("TactileMac source is released under the MIT License. See the bundled LICENSE file.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open notices") { openBundled("THIRD_PARTY_NOTICES") }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Bundled audio")
                            .font(.system(.headline, design: .rounded))
                        Text("All four built-in sound packs were synthesized by scripts in this project. No third-party recordings are bundled. The generated audio is released under CC0-1.0.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open asset license") { openBundled("ASSET_LICENSES") }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Verification status")
                        .font(.system(.headline, design: .rounded))
                    verification("Automated", "JSON parsing, legacy V1/V2 and extended V2 conversion, path traversal rejection, segment validation, OGG decoding, settings persistence, and coordinator deduplication are covered by tests in this repository.")
                    verification("Manual", "Audible output and physical haptics require an in-person check. The app provides preview/test buttons but cannot determine whether you heard or felt them.")
                    verification("Not claimed", "This build is not Developer ID signed or notarized in the current environment. See docs/RELEASE.md for the remaining release steps.")
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Privacy")
                        .font(.system(.headline, design: .rounded))
                    Text("TactileMac has no network client and no telemetry. It never reads typed characters. It processes only the hardware key code, modifier state, button number, and scroll delta needed to produce feedback, then discards them. Settings and imported packs stay in ~/Library/Application Support/TactileMac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Application Support") { model.openDataFolder() }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }
        }
    }

    private func verification(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.purple)
                .frame(width: 78, alignment: .leading)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func openBundled(_ name: String) {
        let url = Bundle.main.url(forResource: name, withExtension: "md", subdirectory: "Notices")
            ?? Bundle.main.url(forResource: name, withExtension: "md")
            ?? Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "Notices")
        if let url {
            NSWorkspace.shared.open(url)
        } else {
            model.alert = AppAlert(title: "Notices unavailable", message: "The bundled \(name) file was not found.")
        }
    }
}

struct AboutSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Build")
                    KeyValueRow(label: "Version", value: model.appVersion)
                    KeyValueRow(label: "Engine", value: "AudioQueue · Float32 stereo")
                    KeyValueRow(label: "Minimum macOS", value: "14.0")
                    KeyValueRow(label: "License", value: "MIT (source) · CC0 (built-in audio)")
                    KeyValueRow(label: "Signing", value: "Ad-hoc in this environment")
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Privacy")
                    Text("No telemetry. No network. No typed text. Settings and packs live only on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { model.copyDiagnostics() } label: {
                        Label("Copy diagnostics", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    Button { model.openDataFolder() } label: {
                        Label("Open Application Support", systemImage: "folder").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 9) {
                    SectionLabel(text: "Release honesty")
                    Text("The app in this environment was built locally and ad-hoc signed. It is not Developer ID signed or notarized. Developer ID signing and notarization require credentials that are not present here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Physical audio and haptic verification remain manual. Automated tests cannot hear or feel.")
                        .font(.caption)
                        .foregroundStyle(Theme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
