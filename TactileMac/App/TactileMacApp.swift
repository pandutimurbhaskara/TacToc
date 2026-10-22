import AppKit
import SwiftUI

@main
struct TactileMacApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("TactileMac", id: "main") {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 660)
        }
        .defaultSize(width: 1280, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Open Application Support") { model.openDataFolder() }
                Divider()
                Button("Refresh Permissions & Hardware") { model.refreshHardware() }
            }
        }

        MenuBarExtra(isInserted: model.binding(\.showMenuBarExtra)) {
            MenuBarView()
                .environmentObject(model)
        } label: {
            Image(systemName: "keyboard")
        }
        .menuBarExtraStyle(.menu)
    }
}
