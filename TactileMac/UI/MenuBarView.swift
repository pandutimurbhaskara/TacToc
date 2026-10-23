import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Keyboard sounds", isOn: model.binding(\.keyboardEnabled))
        Toggle("Trackpad sounds", isOn: model.binding(\.trackpadEnabled))
        Toggle("Haptics", isOn: model.binding(\.hapticsEnabled))

        Divider()

        Button("Test key sound") { model.previewKeyboard(press: true) }
            .disabled(!model.settings.keyboardEnabled)
        Button("Test haptic") { model.previewHaptic() }
            .disabled(!model.settings.hapticsEnabled)

        Divider()

        Button("Open TactileMac") {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain && $0.title == "TactileMac" }) {
                window.makeKeyAndOrderFront(nil)
            } else {
                openWindow(id: "main")
            }
        }

        Button("Refresh permissions & hardware") { model.refreshHardware() }

        Divider()

        Button("Quit TactileMac") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
