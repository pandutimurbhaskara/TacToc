import AppKit
import SwiftUI

struct PackIconView: View {
    var pack: InstalledPack
    var size: CGFloat = 50

    var body: some View {
        Group {
            if let icon = pack.manifest.icon,
               let image = NSImage(contentsOf: pack.rootURL.appendingPathComponent(icon)) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: pack.isBuiltIn ? [Theme.purple, Theme.purpleDeep] : [Theme.tealDeep, Theme.purpleDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: pack.keyboardEventCount > 0 ? "keyboard" : "cursorarrow.click")
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct PackCard: View {
    @EnvironmentObject private var model: AppModel
    var pack: InstalledPack
    var selectedKeyboard: Bool
    var selectedTrackpad: Bool
    var onRemove: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @State private var warningsExpanded = false

    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 12) {
                    PackIconView(pack: pack, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(pack.name)
                                .font(.system(.headline, design: .rounded))
                                .lineLimit(1)
                            if selectedKeyboard || selectedTrackpad {
                                StatusPill(
                                    text: selectedKeyboard && selectedTrackpad ? "Active both" : (selectedKeyboard ? "Keyboard" : "Trackpad"),
                                    color: Theme.purple
                                )
                            }
                        }
                        Text(pack.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        HStack(spacing: 5) {
                            Text(pack.sourceFormat.shortTitle)
                            if pack.isBuiltIn { Text("· built in") }
                            if let license = pack.manifest.license, !license.isEmpty { Text("· \(license)") }
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 4)
                    if pack.isBuiltIn {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .help("Built-in packs cannot be removed")
                    }
                }

                if let issue = pack.issue {
                    CopyableErrorBox(text: issue)
                } else {
                    HStack(spacing: 12) {
                        count("keyboard", pack.keyboardEventCount)
                        count("cursorarrow.click", pack.trackpadEventCount)
                        count("waveform", pack.audioFileCount)
                        Spacer(minLength: 0)
                    }
                }

                if let description = pack.manifest.description, !description.isEmpty, pack.issue == nil {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !pack.warnings.isEmpty {
                    DisclosureGroup(isExpanded: $warningsExpanded) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(pack.warnings.enumerated()), id: \.offset) { _, warning in
                                Text("• \(warning)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        Text("\(pack.warnings.count) import warning\(pack.warnings.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(Theme.amber)
                    }
                }

                HStack(spacing: 6) {
                    Button {
                        model.previewPack(pack.id, role: pack.keyboardEventCount > 0 ? .keyboard : .trackpad)
                    } label: {
                        if model.previewingPackID == pack.id {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "play.fill")
                        }
                    }
                    .buttonStyle(MiniActionButtonStyle(tint: Theme.purple))
                    .disabled(pack.issue != nil || model.previewingPackID == pack.id)
                    .help("Preview \(pack.name)")
                    .accessibilityLabel("Preview \(pack.name)")
                    .accessibilityIdentifier("pack.\(pack.id).preview")

                    if pack.keyboardEventCount > 0 {
                        Button(selectedKeyboard ? "Keyboard ✓" : "Keyboard") {
                            model.selectPack(pack.id, for: .keyboard)
                        }
                        .buttonStyle(MiniActionButtonStyle(tint: selectedKeyboard ? Theme.teal : Theme.purple, selected: selectedKeyboard))
                        .disabled(pack.issue != nil)
                        .help("Use \(pack.name) for keyboard sounds")
                        .accessibilityLabel("Use \(pack.name) for keyboard sounds")
                        .accessibilityIdentifier("pack.\(pack.id).useKeyboard")
                    }
                    if pack.trackpadEventCount > 0 {
                        Button(selectedTrackpad ? "Trackpad ✓" : "Trackpad") {
                            model.selectPack(pack.id, for: .trackpad)
                        }
                        .buttonStyle(MiniActionButtonStyle(tint: selectedTrackpad ? Theme.teal : Theme.purple, selected: selectedTrackpad))
                        .disabled(pack.issue != nil)
                        .help("Use \(pack.name) for trackpad sounds")
                        .accessibilityLabel("Use \(pack.name) for trackpad sounds")
                        .accessibilityIdentifier("pack.\(pack.id).useTrackpad")
                    }

                    Spacer(minLength: 0)

                    Menu {
                        Button("Reveal in Finder") { model.revealPack(pack) }
                        if !pack.isBuiltIn, let onRemove {
                            Divider()
                            Button("Remove Pack…", role: .destructive, action: onRemove)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 22)
                    .accessibilityLabel("More actions for \(pack.name)")
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(selectedKeyboard || selectedTrackpad ? Theme.purple.opacity(0.55) : Color.clear, lineWidth: 1.5)
        )
    }

    private func count(_ symbol: String, _ value: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 9, weight: .medium))
            Text("\(value)")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(.secondary)
    }
}
