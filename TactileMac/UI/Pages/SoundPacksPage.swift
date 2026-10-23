import SwiftUI
import UniformTypeIdentifiers

struct SoundPacksPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var showImporter = false
    @State private var pendingRemoval: InstalledPack?
    @State private var scanWarningsExpanded = false

    private var builtIn: [InstalledPack] { model.packs.filter(\.isBuiltIn) }
    private var imported: [InstalledPack] { model.packs.filter { !$0.isBuiltIn } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Sound Packs",
                subtitle: "Import a folder or zip. Original files stay untouched; TactileMac stores a normalized manifest beside them.",
                badge: "\(model.packs.count) installed",
                badgeColor: Theme.purple,
                trailing: AnyView(
                    HStack(spacing: 8) {
                        Button {
                            showImporter = true
                        } label: {
                            Label("Import", systemImage: "plus")
                        }
                        .buttonStyle(PrimaryButtonStyle(compact: true))
                        .accessibilityIdentifier("soundPacks.import")
                        Button {
                            model.rescanPacks()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                        .help("Rescan installed packs")
                        .accessibilityIdentifier("soundPacks.rescan")
                    }
                )
            )

            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
               let path = ProcessInfo.processInfo.environment["TACTILEMAC_UI_TEST_IMPORT_PATH"] {
                Button("Import UI Test Pack") {
                    model.beginImport(from: URL(fileURLWithPath: path))
                }
                .buttonStyle(CompactButtonStyle())
                .accessibilityIdentifier("soundPacks.importTestPack")
            }
            #endif

            importStateCard

            Card {
                HStack(alignment: .top, spacing: 18) {
                    selectionColumn(title: "Keyboard pack", pack: model.selectedKeyboardPack, role: .keyboard)
                    Divider().frame(height: 42)
                    selectionColumn(title: "Trackpad pack", pack: model.selectedTrackpadPack, role: .trackpad)
                }
            }

            if !model.packScanWarnings.isEmpty {
                Card {
                    DisclosureGroup(isExpanded: $scanWarningsExpanded) {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(model.packScanWarnings.enumerated()), id: \.offset) { _, warning in
                                Text("• \(warning)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(Theme.amber)
                            Text("\(model.packScanWarnings.count) scan note\(model.packScanWarnings.count == 1 ? "" : "s")")
                                .font(.callout.weight(.semibold))
                        }
                    }
                }
            }

            packSection("Built-in profiles", packs: builtIn, emptyText: "Built-in profiles are missing from this build.")
            packSection("Imported packs", packs: imported, emptyText: "No imported packs yet. Use Import to add a TactileMac, legacy, or extended V2 pack.")

            Card {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundStyle(Theme.purple)
                        Text("Where packs live")
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                    }
                    Text(model.paths.soundPacks.path)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button("Open folder") { model.openDataFolder() }
                            .buttonStyle(CompactButtonStyle())
                        Text("Each imported pack keeps its original config.json and adds tactilemac.pack.json.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.folder, .zip, .json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { model.beginImport(from: url) }
            case .failure(let error):
                model.alert = AppAlert(title: "Import cancelled", message: error.localizedDescription)
            }
        }
        .alert(item: $pendingRemoval) { pack in
            Alert(
                title: Text("Remove “\(pack.name)”?"),
                message: Text("This deletes the installed copy in Application Support. Its original source files are not affected."),
                primaryButton: .destructive(Text("Remove")) { model.removePack(pack) },
                secondaryButton: .cancel()
            )
        }
    }

    @ViewBuilder
    private var importStateCard: some View {
        switch model.importState {
        case .idle:
            EmptyView()
        case .importing(let name):
            Card {
                HStack(spacing: 12) {
                    ProgressView().controlSize(.small)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Importing \(name)")
                            .font(.callout.weight(.semibold))
                        Text("Validating JSON, paths, segment bounds, and audio decoding…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        case .failed(let message):
            InfoBanner(
                title: "Import failed",
                message: message,
                systemImage: "exclamationmark.triangle.fill",
                tint: Theme.coral,
                actionTitle: "Dismiss",
                action: { model.dismissImportState() }
            )
        case .imported(let outcome):
            Card {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(alignment: .top, spacing: 11) {
                        IconTile(systemImage: "checkmark.seal.fill", tint: Theme.teal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Imported \(outcome.pack.name)")
                                .font(.system(.headline, design: .rounded))
                                .accessibilityIdentifier("soundPacks.importSuccess")
                            Text(outcome.sourceDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(outcome.pack.keyboardEventCount) keyboard events · \(outcome.pack.trackpadEventCount) trackpad events · \(outcome.pack.audioFileCount) audio files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Dismiss") { model.dismissImportState() }
                            .buttonStyle(CompactButtonStyle())
                    }
                    if !outcome.warnings.isEmpty {
                        DisclosureGroup("\(outcome.warnings.count) import warning\(outcome.warnings.count == 1 ? "" : "s")") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(outcome.warnings.enumerated()), id: \.offset) { _, warning in
                                    Text("• \(warning)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.amber)
                    }
                    HStack(spacing: 8) {
                        if outcome.pack.keyboardEventCount > 0 {
                            Button("Use for keyboard") { model.useImportedPack(outcome, for: .keyboard) }
                                .buttonStyle(PrimaryButtonStyle(compact: true))
                        }
                        if outcome.pack.trackpadEventCount > 0 {
                            Button("Use for trackpad") { model.useImportedPack(outcome, for: .trackpad) }
                                .buttonStyle(SecondaryButtonStyle(compact: true))
                        }
                        Button("Reveal files") { model.revealPack(outcome.pack) }
                            .buttonStyle(CompactButtonStyle())
                    }
                }
            }
        }
    }

    private func selectionColumn(title: String, pack: InstalledPack?, role: PackRole) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel(text: title)
            Text(pack?.name ?? "None")
                .font(.system(.title3, design: .rounded).weight(.semibold))
            Text(pack?.sourceFormat.title ?? "Choose a pack with matching events")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error = model.packLoadErrors[role == .keyboard ? model.settings.keyboardPackID : model.settings.trackpadPackID] {
                CopyableErrorBox(text: error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func packSection(_ title: String, packs: [InstalledPack], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: title)
                Spacer()
                Text("\(packs.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if packs.isEmpty {
                Card {
                    Text(emptyText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 13)], spacing: 13) {
                    ForEach(packs) { pack in
                        PackCard(
                            pack: pack,
                            selectedKeyboard: pack.id == model.settings.keyboardPackID,
                            selectedTrackpad: pack.id == model.settings.trackpadPackID,
                            onRemove: pack.isBuiltIn ? nil : { pendingRemoval = pack }
                        )
                    }
                }
            }
        }
    }
}

struct SoundPacksSettings: View {
    @EnvironmentObject private var model: AppModel
    @State private var showImporter = false

    var body: some View {
        VStack(spacing: 14) {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Import")
                    Text("Folders, .zip archives, and config files are accepted. Every referenced audio file is decoded during import; unsupported keys and missing files are reported.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import sound pack…", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                    .accessibilityIdentifier("soundPacks.settings.import")
                    Button {
                        model.rescanPacks()
                    } label: {
                        Label("Rescan installed packs", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    Button {
                        model.openDataFolder()
                    } label: {
                        Label("Open Application Support", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Selection")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Keyboard pack").font(.callout)
                        Picker("Keyboard pack", selection: model.binding(\.keyboardPackID)) {
                            ForEach(model.keyboardPackOptions) { Text($0.name).tag($0.id) }
                        }
                        .labelsHidden().pickerStyle(.menu)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trackpad pack").font(.callout)
                        Picker("Trackpad pack", selection: model.binding(\.trackpadPackID)) {
                            ForEach(model.trackpadPackOptions) { Text($0.name).tag($0.id) }
                        }
                        .labelsHidden().pickerStyle(.menu)
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Format facts")
                    fact("Native schema", "tactilemac.pack v1")
                    fact("Decoded formats", "Ogg Vorbis, WAV, MP3, FLAC (as supported by AVFoundation)")
                    fact("Timing", "Native startMs + durationMs; legacy packs converted to milliseconds")
                    fact("Original files", "Never rewritten")
                    fact("Unsafe paths", "Rejected, including .. and symlinks")
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.folder, .zip, .json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { model.beginImport(from: url) }
            case .failure(let error):
                model.alert = AppAlert(title: "Import cancelled", message: error.localizedDescription)
            }
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        KeyValueRow(label: label, value: value)
    }
}
