import SwiftUI

struct ProfilesPage: View {
    @EnvironmentObject private var model: AppModel

    private var builtIn: [InstalledPack] {
        model.packs.filter { $0.isBuiltIn }
    }

    private var imported: [InstalledPack] {
        model.packs.filter { !$0.isBuiltIn }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Sound Profiles",
                subtitle: "Four original built-in profiles plus anything you import. Keyboard and trackpad can use different packs.",
                badge: "\(model.packs.count) installed",
                badgeColor: Theme.purple
            )

            Card {
                HStack(alignment: .center, spacing: 16) {
                    PackIconView(pack: model.selectedKeyboardPack ?? builtIn.first ?? emptyPack, size: 58)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Keyboard profile")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(model.selectedKeyboardPack?.name ?? "None selected")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .accessibilityIdentifier("profiles.selectedKeyboardPack")
                        Text(model.selectedKeyboardPack?.manifest.description ?? "Choose a usable pack below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("\(model.selectedKeyboardPack?.keyboardEventCount ?? 0) key events")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Preview") { model.previewKeyboard(press: true) }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "Built-in profiles")
                    Spacer()
                    Text("Generated from original synthesis · CC0-1.0")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 13)], spacing: 13) {
                    ForEach(builtIn) { pack in
                        PackCard(
                            pack: pack,
                            selectedKeyboard: pack.id == model.settings.keyboardPackID,
                            selectedTrackpad: pack.id == model.settings.trackpadPackID
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "Imported packs")
                    Spacer()
                    Button("Import in Sound Packs") { model.selectedPage = .soundPacks }
                        .buttonStyle(CompactButtonStyle())
                }
                if imported.isEmpty {
                    Card {
                        HStack(spacing: 13) {
                            IconTile(systemImage: "shippingbox", tint: Theme.teal)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("No imported packs yet")
                                    .font(.system(.callout, design: .rounded).weight(.semibold))
                                Text("Import a TactileMac pack, a legacy pack, or an extended V2 folder.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Open Sound Packs") { model.selectedPage = .soundPacks }
                                .buttonStyle(SecondaryButtonStyle(compact: true))
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 13)], spacing: 13) {
                        ForEach(imported) { pack in
                            PackCard(
                                pack: pack,
                                selectedKeyboard: pack.id == model.settings.keyboardPackID,
                                selectedTrackpad: pack.id == model.settings.trackpadPackID
                            )
                        }
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A note on names")
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                    Text("The built-in Thock, Clicky, Linear, and Soft profiles are original synthesized sound sets. They are not recordings of the switches whose character inspired their names, and no authenticity is claimed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var emptyPack: InstalledPack {
        InstalledPack(
            id: "empty",
            manifest: PackManifest(id: "empty", name: "No pack", author: "", events: [:]),
            rootURL: URL(fileURLWithPath: "/"),
            isBuiltIn: true,
            sourceFormat: .tactilemac,
            warnings: [],
            issue: nil
        )
    }
}

struct ProfilesSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Card {
                VStack(alignment: .leading, spacing: 13) {
                    SectionLabel(text: "Assignments")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Keyboard pack").font(.callout)
                        Picker("Keyboard pack", selection: model.binding(\.keyboardPackID)) {
                            ForEach(model.keyboardPackOptions) { pack in
                                Text(pack.name).tag(pack.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trackpad pack").font(.callout)
                        Picker("Trackpad pack", selection: model.binding(\.trackpadPackID)) {
                            ForEach(model.trackpadPackOptions) { pack in
                                Text(pack.name).tag(pack.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    if let error = model.packLoadErrors[model.settings.keyboardPackID] {
                        CopyableErrorBox(text: error)
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Levels")
                    SliderRow(
                        title: "Keyboard",
                        value: model.binding(\.keyboardVolume),
                        range: 0...1,
                        display: "\(Int(model.settings.keyboardVolume * 100))%"
                    )
                    Divider()
                    SliderRow(
                        title: "Trackpad",
                        value: model.binding(\.trackpadVolume),
                        range: 0...1,
                        display: "\(Int(model.settings.trackpadVolume * 100))%"
                    )
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Selected pack details")
                    if let pack = model.selectedKeyboardPack {
                        detail("Name", pack.name)
                        detail("Author", pack.author)
                        detail("Source", pack.sourceFormat.title)
                        detail("License", pack.manifest.license ?? "Not stated")
                        detail("Keyboard events", "\(pack.keyboardEventCount)")
                        detail("Trackpad events", "\(pack.trackpadEventCount)")
                    } else {
                        Text("No usable keyboard pack is selected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
    }
}
