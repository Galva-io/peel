import SwiftUI
import PeelCore
import PeelAPI

public struct MainContent: View {
    @Bindable public var store: PeelAppStore

    public init(store: PeelAppStore) { self.store = store }

    public var body: some View {
        Group {
            if let selection = store.sidebarSelection, store.activeApp != nil {
                detail(for: selection)
            } else {
                EmptyStatePanel(hasApps: !store.apps.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func detail(for selection: SidebarSelection) -> some View {
        HSplitView {
            RequestPanel(store: store, selection: selection)
                .frame(minWidth: 360, idealWidth: 420)

            ResponseViewer(store: store, selection: selection)
        }
    }
}

/// Fills the entire detail panel when the user hasn't picked an endpoint
/// yet. Always offers an Add App button so a brand-new install has an
/// obvious way forward without hunting through menus.
struct EmptyStatePanel: View {
    let hasApps: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                ctaRow
                tipsCard
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: hasApps ? "sidebar.left" : "drop.degreesign")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tint)
            Text(hasApps ? "Pick an endpoint" : "Welcome to Peel")
                .font(.system(size: 26, weight: .semibold))
            Text(description)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var description: String {
        hasApps
            ? "Choose an endpoint under one of your apps in the sidebar to make your first call."
            : "Peel is a workbench for Apple's App Store Server API. Add an app context and you'll have signed JWTs, decoded responses, and a webhook receiver in one place."
    }

    private var ctaRow: some View {
        HStack(spacing: 10) {
            Button {
                NotificationCenter.default.post(name: .peelAddAppRequested, object: nil)
            } label: {
                Label(hasApps ? "Add Another App" : "Add an App", systemImage: "plus")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 6)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Link(destination: URL(string: "https://developer.apple.com/documentation/appstoreserverapi")!) {
                Label("API docs", systemImage: "book.closed")
            }
            .controlSize(.large)

            Spacer()
        }
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tips")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            tipRow("⌘↩", "Send the current request")
            tipRow("⌘⌃E", "Toggle Sandbox / Production")
            tipRow("⌘⌃R", "Toggle read-only mode")
            tipRow("⌘⇧M", "Mark a response for compare")
            tipRow("⌥-click", "Copy any value in the decoded view")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private func tipRow(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 10) {
            Text(keys)
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .frame(minWidth: 70, alignment: .leading)
            Text(label).font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
    }
}
