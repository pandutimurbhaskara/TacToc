import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    private let primaryPages: [AppPage] = [.overview, .profiles, .keyboard, .trackpad, .haptics, .soundPacks]
    private let systemPages: [AppPage] = [.advanced, .permissions, .about]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.purple, Theme.purpleDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)
                .shadow(color: Theme.purple.opacity(0.3), radius: 7, y: 3)

                VStack(alignment: .leading, spacing: 1) {
                    Text("TactileMac")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("sound · feel · input")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 18)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    SectionLabel(text: "Workspace")
                        .padding(.horizontal, 18)
                        .padding(.bottom, 5)
                    ForEach(primaryPages) { page in
                        row(for: page)
                    }

                    SectionLabel(text: "System")
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 5)
                    ForEach(systemPages) { page in
                        row(for: page)
                    }
                }
                .padding(.bottom, 14)
            }

            Spacer(minLength: 8)

            permissionFooter
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            HStack {
                Text("v\(model.appVersion)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Main window")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .frame(width: Theme.sidebarWidth)
        .background(Theme.sidebarBackground.opacity(colorScheme == .dark ? 0.65 : 0.72))
    }

    private func row(for page: AppPage) -> some View {
        let selected = model.selectedPage == page
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) { model.selectedPage = page }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: page.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 19)
                    .foregroundStyle(selected ? Theme.purple : .secondary)
                Text(page.title)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if page == .permissions && model.permissions.inputMonitoring != .granted && model.needsInputMonitoring {
                    Circle().fill(Theme.amber).frame(width: 6, height: 6)
                }
            }
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Theme.purple.opacity(colorScheme == .dark ? 0.22 : 0.12) : Color.clear)
            )
            .overlay(alignment: .leading) {
                if selected {
                    Capsule().fill(Theme.purple).frame(width: 2.5, height: 16).offset(x: 2)
                }
            }
            .padding(.horizontal, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sidebar.\(page.rawValue)")
    }

    private var permissionFooter: some View {
        let granted = model.permissions.inputMonitoring == .granted
        let tint = granted ? Theme.teal : Theme.amber
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Circle().fill(tint).frame(width: 6, height: 6)
                Text(granted ? "Input Monitoring on" : "Input Monitoring needed")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
            }
            Text(granted ? "Global key and pointer events are available." : "Open Permissions & Hardware to enable keyboard sounds.")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Review permissions") { model.selectedPage = .permissions }
                .buttonStyle(CompactButtonStyle(tint: tint))
                .accessibilityIdentifier("sidebar.reviewPermissions")
        }
        .padding(10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
