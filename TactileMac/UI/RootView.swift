import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                SidebarView()
                Rectangle().fill(Theme.divider).frame(width: 1)
                if proxy.size.width >= 1180 {
                    wideContent
                } else {
                    narrowContent
                }
            }
            .background(Theme.background)
        }
        .frame(minWidth: 980, minHeight: 660)
        .alert(item: $model.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .onChange(of: model.selectedPage) { _, page in
            if page == .permissions || page == .advanced { model.refreshHardware() }
        }
    }

    private var wideContent: some View {
        HStack(spacing: 0) {
            ScrollView(.vertical) {
                center(for: model.selectedPage)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.automatic)

            Rectangle().fill(Theme.divider).frame(width: 1)

            ScrollView(.vertical) {
                SettingsPanel(page: model.selectedPage)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 22)
            }
            .frame(width: Theme.rightPanelWidth)
            .background(Theme.sidebarBackground.opacity(0.30))
        }
    }

    private var narrowContent: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                center(for: model.selectedPage)
                Divider()
                SettingsPanel(page: model.selectedPage)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func center(for page: AppPage) -> some View {
        Group {
            switch page {
            case .overview: OverviewPage()
            case .profiles: ProfilesPage()
            case .keyboard: KeyboardPage()
            case .trackpad: TrackpadPage()
            case .haptics: HapticsPage()
            case .soundPacks: SoundPacksPage()
            case .advanced: AdvancedPage()
            case .permissions: PermissionsPage()
            case .about: AboutPage()
            }
        }
    }
}

struct SettingsPanel: View {
    var page: AppPage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                Text(page.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            switch page {
            case .overview: OverviewSettings()
            case .profiles: ProfilesSettings()
            case .keyboard: KeyboardSettings()
            case .trackpad: TrackpadSettings()
            case .haptics: HapticsSettings()
            case .soundPacks: SoundPacksSettings()
            case .advanced: AdvancedSettings()
            case .permissions: PermissionsSettings()
            case .about: AboutSettings()
            }
        }
    }
}
