import AppKit
import Combine
import Foundation
import QuartzCore
import SwiftUI

enum AppPage: String, CaseIterable, Identifiable {
    case overview
    case profiles
    case keyboard
    case trackpad
    case haptics
    case soundPacks
    case advanced
    case permissions
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .profiles: return "Sound Profiles"
        case .keyboard: return "Keyboard Sounds"
        case .trackpad: return "Trackpad Sounds"
        case .haptics: return "Haptics"
        case .soundPacks: return "Sound Packs"
        case .advanced: return "Advanced"
        case .permissions: return "Permissions & Hardware"
        case .about: return "License & About"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .profiles: return "waveform"
        case .keyboard: return "keyboard"
        case .trackpad: return "hand.tap"
        case .haptics: return "iphone.radiowaves.left.and.right"
        case .soundPacks: return "shippingbox"
        case .advanced: return "slider.horizontal.3"
        case .permissions: return "checkmark.shield"
        case .about: return "info.circle"
        }
    }
}

enum PackRole {
    case keyboard
    case trackpad
}

enum ImportState {
    case idle
    case importing(String)
    case imported(ImportOutcome)
    case failed(String)
}

struct PermissionSnapshot: Equatable {
    var inputMonitoring: InputMonitoringStatus = .unknown
    var accessibilityTrusted = false
    var secureInputActive = false
    var tapRunning = false
    var tapError: String?
}

struct AppAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

final class AppModel: ObservableObject {
    let paths: AppPaths
    let settingsStore: SettingsStore
    let audio: AudioEngine
    let haptics: HapticEngine
    let coordinator: FeedbackCoordinator
    let inputMonitor: InputMonitor
    let repository: PackRepository
    let importer: PackImportService

    @Published private(set) var settings: AppSettings
    @Published var selectedPage: AppPage = .overview
    @Published private(set) var packs: [InstalledPack] = []
    @Published private(set) var packScanWarnings: [String] = []
    @Published private(set) var packLoadErrors: [String: String] = [:]
    @Published private(set) var settingsWarning: String?
    @Published private(set) var engineError: String?
    @Published private(set) var permissions = PermissionSnapshot()
    @Published private(set) var trackpad = TrackpadCapability()
    @Published private(set) var audioInfo = AudioOutputInfo()
    @Published private(set) var input = LiveInputSnapshot()
    @Published private(set) var importState: ImportState = .idle
    @Published private(set) var previewingPackID: String?
    @Published private(set) var lastImport: ImportOutcome?
    @Published var alert: AppAlert?

    private var saveWork: DispatchWorkItem?
    private var permissionTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var packLoadGeneration = 0
    private var inputStartBlocked = false
    private var lastRecordTime: TimeInterval = 0
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")

    init(paths: AppPaths = AppPaths()) {
        self.paths = paths
        self.settingsStore = SettingsStore(paths: paths)
        let loaded = settingsStore.load()
        var initialSettings = loaded.settings
        initialSettings.clamp()
        self.settings = initialSettings
        self.settingsWarning = loaded.warning

        self.audio = AudioEngine(bufferFrames: initialSettings.audioBufferFrames)
        self.haptics = HapticEngine()
        self.coordinator = FeedbackCoordinator(audio: audio, haptics: haptics)
        self.inputMonitor = InputMonitor()
        self.repository = PackRepository(paths: paths)
        self.importer = PackImportService(paths: paths)

        do { try paths.prepare() }
        catch { settingsWarning = (settingsWarning.map { $0 + " " } ?? "") + "The Application Support folder could not be created: \(error.localizedDescription)" }

        let scan = repository.scan()
        self.packs = scan.packs
        self.packScanWarnings = scan.warnings
        ensureSelections()
        applySettings(previous: nil, reloadPacks: false)

        wireInput()
        startTimers()
        wireNotifications()
        refreshRuntimeState(checkPermission: true)
        reloadActivePacks()
        startInputIfPossible()
        scheduleSave()
    }

    deinit {
        permissionTimer?.invalidate()
        saveWork?.cancel()
        inputMonitor.stop()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    // MARK: - Bindings and mutations

    func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { value in self.update(keyPath, value) }
        )
    }

    func update<T>(_ keyPath: WritableKeyPath<AppSettings, T>, _ value: T) {
        let previous = settings
        var next = settings
        next[keyPath: keyPath] = value
        next.clamp()
        guard next != previous else { return }
        settings = next
        applySettings(previous: previous, reloadPacks: previous.keyboardPackID != next.keyboardPackID || previous.trackpadPackID != next.trackpadPackID)
        scheduleSave()
    }

    private func applySettings(previous: AppSettings?, reloadPacks: Bool) {
        coordinator.apply(settings)
        audio.setVolumes(keyboard: Float(settings.keyboardVolume), trackpad: Float(settings.trackpadVolume))
        audio.setActivePacks(keyboard: settings.keyboardPackID, trackpad: settings.trackpadPackID)
        if let previous, previous.audioBufferFrames != settings.audioBufferFrames {
            audio.setBufferFrames(settings.audioBufferFrames)
        }
        if reloadPacks { reloadActivePacks() }
        if previous == nil || previous?.keyboardEnabled != settings.keyboardEnabled
            || previous?.trackpadEnabled != settings.trackpadEnabled
            || previous?.hapticsEnabled != settings.hapticsEnabled
            || previous?.hapticOnKeyboard != settings.hapticOnKeyboard
            || previous?.hapticOnTrackpadClicks != settings.hapticOnTrackpadClicks
            || previous?.hapticOnScroll != settings.hapticOnScroll {
            reconcileInputMonitoring()
        }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let snapshot = settings
        let store = settingsStore
        let work = DispatchWorkItem {
            do { try store.save(snapshot) } catch { NSLog("TactileMac: settings save failed: \(error)") }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func flushSettings() {
        saveWork?.cancel()
        do { try settingsStore.save(settings) } catch { NSLog("TactileMac: settings flush failed: \(error)") }
    }

    // MARK: - Packs

    var keyboardPackOptions: [InstalledPack] {
        packs.filter { $0.isUsable && $0.keyboardEventCount > 0 }
    }

    var trackpadPackOptions: [InstalledPack] {
        packs.filter { $0.isUsable && $0.trackpadEventCount > 0 }
    }

    func pack(id: String) -> InstalledPack? {
        packs.first { $0.id == id }
    }

    var selectedKeyboardPack: InstalledPack? { pack(id: settings.keyboardPackID) }
    var selectedTrackpadPack: InstalledPack? { pack(id: settings.trackpadPackID) }

    private func ensureSelections() {
        let keyboard = packs.filter { $0.isUsable && $0.keyboardEventCount > 0 }
        if !keyboard.contains(where: { $0.id == settings.keyboardPackID }) {
            settings.keyboardPackID = keyboard.first(where: { $0.isBuiltIn })?.id ?? keyboard.first?.id ?? settings.keyboardPackID
        }
        let trackpad = packs.filter { $0.isUsable && $0.trackpadEventCount > 0 }
        if !trackpad.contains(where: { $0.id == settings.trackpadPackID }) {
            settings.trackpadPackID = trackpad.first(where: { $0.isBuiltIn })?.id ?? trackpad.first?.id ?? settings.trackpadPackID
        }
    }

    func selectPack(_ id: String, for role: PackRole) {
        switch role {
        case .keyboard: update(\.keyboardPackID, id)
        case .trackpad: update(\.trackpadPackID, id)
        }
    }

    private func reloadActivePacks() {
        packLoadGeneration += 1
        let generation = packLoadGeneration
        let keyboardID = settings.keyboardPackID
        let trackpadID = settings.trackpadPackID
        let byID = Dictionary(uniqueKeysWithValues: packs.map { ($0.id, $0) })
        let needed = Array(Set([keyboardID, trackpadID]))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var loaded: [LoadedPack] = []
            var errors: [String: String] = [:]
            for id in needed {
                guard let pack = byID[id] else {
                    errors[id] = "The selected pack is not installed."
                    continue
                }
                if let issue = pack.issue {
                    errors[id] = issue
                    continue
                }
                do {
                    let result = try PackLoader().load(manifest: pack.manifest, root: pack.rootURL, sourceFormat: pack.sourceFormat)
                    loaded.append(result)
                } catch {
                    errors[id] = error.localizedDescription
                }
            }
            DispatchQueue.main.async {
                guard generation == self.packLoadGeneration else { return }
                for pack in loaded { self.audio.install(pack) }
                self.audio.setActivePacks(keyboard: keyboardID, trackpad: trackpadID)
                self.packLoadErrors = errors
                self.engineError = self.audio.lastError
            }
        }
    }

    func rescanPacks() {
        let scan = repository.scan()
        packs = scan.packs
        packScanWarnings = scan.warnings
        ensureSelections()
        scheduleSave()
        reloadActivePacks()
    }

    func previewPack(_ id: String, role: PackRole, eventKeys: [String]? = nil) {
        let keys: [String]
        if let eventKeys {
            keys = eventKeys
        } else {
            switch role {
            case .keyboard:
                keys = ["key.down.KeyA", "key.down.letter", "key.down.default"]
            case .trackpad:
                keys = ["trackpad.click.left", "trackpad.click.default"]
            }
        }
        let volume = Float(role == .keyboard ? settings.keyboardVolume : settings.trackpadVolume)
        if audio.preview(packID: id, eventKeys: keys, volume: volume) { return }
        guard let pack = pack(id: id), pack.isUsable else {
            alert = AppAlert(title: "Preview unavailable", message: packLoadErrors[id] ?? "This pack is not installed or has no sound for this event.")
            return
        }
        previewingPackID = id
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let loaded = try PackLoader().load(manifest: pack.manifest, root: pack.rootURL, sourceFormat: pack.sourceFormat)
                DispatchQueue.main.async {
                    self.audio.install(loaded)
                    self.previewingPackID = nil
                    if !self.audio.preview(packID: id, eventKeys: keys, volume: volume) {
                        self.alert = AppAlert(title: "Preview unavailable", message: "This pack has no playable clip for the preview event.")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.previewingPackID = nil
                    self.packLoadErrors[id] = error.localizedDescription
                    self.alert = AppAlert(title: "Preview failed", message: error.localizedDescription)
                }
            }
        }
    }

    func previewKeyboard(press: Bool) {
        let keys = press
            ? ["key.down.KeyA", "key.down.letter", "key.down.default"]
            : ["key.up.KeyA", "key.up.letter", "key.up.default"]
        previewSelected(role: .keyboard, keys: keys)
    }

    func previewTrackpadClick(_ button: MouseButtonName = .left) {
        previewSelected(role: .trackpad, keys: PackEvent.click(button))
    }

    func previewTrackpadScroll(_ direction: String) {
        previewSelected(role: .trackpad, keys: PackEvent.scroll(direction: direction))
    }

    private func previewSelected(role: PackRole, keys: [String]) {
        let id = role == .keyboard ? settings.keyboardPackID : settings.trackpadPackID
        let volume = Float(role == .keyboard ? settings.keyboardVolume : settings.trackpadVolume)
        if audio.preview(packID: id, eventKeys: keys, volume: volume) { return }
        previewPack(id, role: role, eventKeys: keys)
    }

    func previewHaptic() {
        haptics.tick(settings.hapticPattern)
    }

    // MARK: - Import and removal

    func beginImport(from url: URL) {
        importState = .importing(url.lastPathComponent)
        let existing = Set(packs.map(\.id))
        let importer = self.importer
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let outcome = try importer.importPack(from: url, reservedIDs: existing)
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.importState = .imported(outcome)
                    self.lastImport = outcome
                    self.rescanPacks()
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.importState = .failed(error.localizedDescription)
                }
            }
        }
    }

    func dismissImportState() {
        importState = .idle
    }

    func useImportedPack(_ outcome: ImportOutcome, for role: PackRole) {
        let hasKeyboard = outcome.pack.keyboardEventCount > 0
        let hasTrackpad = outcome.pack.trackpadEventCount > 0
        switch role {
        case .keyboard where hasKeyboard: selectPack(outcome.pack.id, for: .keyboard)
        case .trackpad where hasTrackpad: selectPack(outcome.pack.id, for: .trackpad)
        default:
            alert = AppAlert(title: "No matching sounds", message: "This pack does not contain \(role == .keyboard ? "keyboard" : "trackpad") events.")
        }
    }

    func removePack(_ pack: InstalledPack) {
        guard !pack.isBuiltIn else {
            alert = AppAlert(title: "Built-in pack", message: "Built-in packs are part of the app and cannot be removed. You can switch to another pack at any time.")
            return
        }
        let fallback = packs.first(where: { $0.isBuiltIn && $0.isUsable && $0.keyboardEventCount > 0 })
        if settings.keyboardPackID == pack.id, let fallback { settings.keyboardPackID = fallback.id }
        if settings.trackpadPackID == pack.id, let fallback { settings.trackpadPackID = fallback.id }
        do {
            try FileManager.default.removeItem(at: pack.rootURL)
            audio.unloadPack(id: pack.id)
            rescanPacks()
        } catch {
            alert = AppAlert(title: "Could not remove pack", message: error.localizedDescription)
        }
    }

    func revealPack(_ pack: InstalledPack) {
        NSWorkspace.shared.activateFileViewerSelecting([pack.rootURL])
    }

    func openDataFolder() {
        NSWorkspace.shared.open(paths.applicationSupport)
    }

    func refreshHardware() {
        refreshRuntimeState(checkPermission: true)
        audioInfo = audio.outputInfo
        trackpad = CapabilityService.trackpad()
    }

    // MARK: - Permissions and runtime

    var needsInputMonitoring: Bool {
        settings.keyboardEnabled
            || settings.trackpadEnabled
            || (settings.hapticsEnabled && (settings.hapticOnKeyboard || settings.hapticOnTrackpadClicks || settings.hapticOnScroll))
    }

    func requestInputMonitoring() {
        update(\.hasSeenPermissionGuidance, true)
        inputStartBlocked = false
        _ = PermissionService.requestInputMonitoring()
        refreshRuntimeState()
        startInputIfPossible()
    }

    func retryInputTap() {
        inputStartBlocked = false
        permissions.tapError = nil
        startInputIfPossible()
    }

    func openInputMonitoringSettings() {
        PermissionService.openInputMonitoringSettings()
    }

    func openAccessibilitySettings() {
        PermissionService.openAccessibilitySettings()
    }

    func markPermissionGuidanceSeen() {
        if !settings.hasSeenPermissionGuidance { update(\.hasSeenPermissionGuidance, true) }
    }

    private func wireInput() {
        inputMonitor.onEvent = { [weak self] event in
            guard let self else { return }
            let result = self.coordinator.handle(event)
            if case .scroll = event, !result.soundPlayed, !result.hapticPlayed { return }
            DispatchQueue.main.async { self.record(event: event, result: result) }
        }
        inputMonitor.onError = { [weak self] message in
            DispatchQueue.main.async {
                guard let self else { return }
                self.permissions.tapError = message
            }
        }
        inputMonitor.onRunningChanged = { [weak self] running in
            DispatchQueue.main.async {
                guard let self else { return }
                self.permissions.tapRunning = running
                self.permissions.tapError = running ? nil : self.permissions.tapError
            }
        }
    }

    private func startTimers() {
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshRuntimeState()
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    private func wireNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        let wake = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.audio.handleWake()
            self?.refreshRuntimeState(checkPermission: true)
        }
        let activate = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshRuntimeState(checkPermission: true)
        }
        let terminate = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.flushSettings()
        }
        observers = [wake, activate, terminate]
    }

    private func refreshRuntimeState(checkPermission: Bool = false) {
        // IOHIDCheckAccess reaches tccd; polling it would generate needless TCC
        // traffic. Callers check permissions on launch, app activation, the
        // Permissions page, and explicit refresh. The periodic timer only
        // refreshes cheap local state.
        let status = checkPermission ? PermissionService.inputMonitoringStatus() : permissions.inputMonitoring
        let accessibility = checkPermission ? PermissionService.accessibilityTrusted() : permissions.accessibilityTrusted
        let secure = PermissionService.secureInputActive()
        let running = inputMonitor.isRunning
        let snapshot = PermissionSnapshot(
            inputMonitoring: status,
            accessibilityTrusted: accessibility,
            secureInputActive: secure,
            tapRunning: running,
            tapError: permissions.tapError
        )
        let trackpadInfo = CapabilityService.trackpad()
        let output = audio.outputInfo
        let error = audio.lastError

        if permissions != snapshot { permissions = snapshot }
        if trackpad != trackpadInfo { trackpad = trackpadInfo }
        if audioInfo != output { audioInfo = output }
        if engineError != error { engineError = error }
        if input.secureInputActive != secure {
            input.secureInputActive = secure
        }

        reconcileInputMonitoring(status: status)
    }

    private func reconcileInputMonitoring(status: InputMonitoringStatus? = nil) {
        if isUITesting { return }
        let current = status ?? permissions.inputMonitoring
        if !needsInputMonitoring {
            if inputMonitor.isRunning { inputMonitor.stop() }
            return
        }
        if current != .granted {
            if inputMonitor.isRunning { inputMonitor.stop() }
            return
        }
        startInputIfPossible(status: current)
    }

    private func startInputIfPossible(status: InputMonitoringStatus? = nil) {
        if isUITesting { return }
        guard needsInputMonitoring else { return }
        let current = status ?? permissions.inputMonitoring
        guard current == .granted else { return }
        guard !inputMonitor.isRunning, !inputStartBlocked else { return }
        if !inputMonitor.start() {
            inputStartBlocked = true
            permissions.tapRunning = false
            if permissions.tapError == nil {
                permissions.tapError = "The event tap could not be created. Check Input Monitoring and relaunch TactileMac if needed."
            }
        } else {
            permissions.tapRunning = true
            permissions.tapError = nil
        }
    }

    // MARK: - Statistics

    private func record(event: NormalizedInputEvent, result: FeedbackResult) {
        let now = CACurrentMediaTime()
        let isScroll: Bool
        switch event {
        case .keyDown:
            input.keyboardEventCount += 1
            isScroll = false
            input.lastEvent = .init(kind: .keyDown, detail: "keyboard", timestamp: Date())
        case .keyUp:
            input.keyboardEventCount += 1
            isScroll = false
            input.lastEvent = .init(kind: .keyUp, detail: "keyboard", timestamp: Date())
        case .modifierChanged:
            input.keyboardEventCount += 1
            isScroll = false
            input.lastEvent = .init(kind: .modifier, detail: "modifier", timestamp: Date())
        case .mouseButton(let button, let isDown, _):
            input.trackpadEventCount += 1
            isScroll = false
            if isDown { input.lastEvent = .init(kind: .click, detail: button.rawValue, timestamp: Date()) }
        case .scroll(let delta, _, _, _):
            input.trackpadEventCount += 1
            isScroll = true
            if result.soundPlayed { input.lastEvent = .init(kind: .scroll, detail: delta > 0 ? "up" : "down", timestamp: Date()) }
        }
        if result.soundPlayed { input.soundCount += 1 }
        if result.hapticPlayed { input.hapticCount += 1 }
        if result.dropped && !result.soundPlayed && !result.hapticPlayed,
           result.reason != "Button release",
           result.reason != "Scroll accumulator below threshold" {
            input.droppedCount += 1
        }
        if result.soundPlayed {
            let latency = audio.latencySnapshot()
            input.lastEngineLatencyMs = latency.last
            input.averageEngineLatencyMs = latency.average
        }
        if isScroll && !result.soundPlayed && !result.hapticPlayed {
            // Scroll generates many upstream events; do not repaint for the
            // ones that did not produce feedback.
        }
        lastRecordTime = now
    }

    // MARK: - Settings reset / diagnostics

    func resetSettings() {
        let previous = settings
        settings = AppSettings()
        applySettings(previous: previous, reloadPacks: true)
        scheduleSave()
        refreshRuntimeState()
    }

    var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var secureInputStatusText: String {
        permissions.secureInputActive ? "Active — macOS is hiding keystrokes from all apps" : "Inactive"
    }

    func copyDiagnostics() {
        let status = [
            "TactileMac \(appVersion)",
            "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Input Monitoring: \(permissions.inputMonitoring.title)",
            "Event tap running: \(permissions.tapRunning)",
            "Secure Event Input: \(permissions.secureInputActive)",
            "Trackpad detected: \(trackpad.detected), actuation reported: \(trackpad.actuationReported), embedded: \(trackpad.embedded)",
            "Audio: \(audioInfo.deviceName), \(Int(audioInfo.sampleRate)) Hz, \(audioInfo.hardwareBufferFrames) frames, estimated output latency \(String(format: "%.1f", audioInfo.computedOutputLatencyMs)) ms",
            "Keyboard pack: \(settings.keyboardPackID)",
            "Trackpad pack: \(settings.trackpadPackID)",
            "Installed packs: \(packs.map(\.id).joined(separator: ", "))"
        ].joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(status, forType: .string)
        alert = AppAlert(title: "Diagnostics copied", message: "A summary without keystrokes, text input, or personal identifiers was copied to the clipboard.")
    }
}
