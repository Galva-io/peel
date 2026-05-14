import SwiftUI
import PeelCore
import PeelPersistence

public struct SidebarView: View {
    @Bindable public var store: PeelAppStore
    @State private var showingAddApp = false

    public init(store: PeelAppStore) { self.store = store }

    public var body: some View {
        List(selection: $store.activeAppId) {
            Section("Apps") {
                ForEach(store.apps) { app in
                    SidebarRow(app: app)
                        .tag(app.id)
                        .contextMenu {
                            Button("Edit App Settings…") {
                                // Routed via NotificationCenter; the main window listens.
                                NotificationCenter.default.post(name: .peelEditApp, object: app.id)
                            }
                            Button(app.isPinned ? "Unpin" : "Pin") {
                                var updated = app
                                updated.isPinned.toggle()
                                Task { try? await store.updateApp(updated) }
                            }
                            Divider()
                            Button("Delete…", role: .destructive) {
                                NotificationCenter.default.post(name: .peelDeleteApp, object: app.id)
                            }
                        }
                }
            }

            if !store.history.isEmpty {
                Section("Recent History") {
                    ForEach(store.history.prefix(20)) { record in
                        HistoryRow(record: record)
                            .onTapGesture(count: 2) {
                                NotificationCenter.default.post(name: .peelReplayHistory, object: record.id)
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
        .toolbar {
            ToolbarItem {
                Button {
                    showingAddApp = true
                } label: {
                    Label("Add App", systemImage: "plus")
                }
                .help("Add a new App Store Connect app context")
            }
        }
        .sheet(isPresented: $showingAddApp) {
            AddAppSheet(store: store, isPresented: $showingAddApp)
        }
    }
}

struct SidebarRow: View {
    let app: AppConfig

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: app.accentColorHex) ?? .accentColor)
                .frame(width: 16, height: 16)
                .overlay(
                    Text(String(app.displayName.prefix(1)).uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(app.displayName).font(.body)
                    if app.isPinned {
                        Image(systemName: "pin.fill")
                            .imageScale(.small)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(app.bundleId)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .accessibilityLabel("App \(app.displayName), bundle \(app.bundleId)")
    }
}

struct HistoryRow: View {
    let record: Storage.HistoryRecord

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(record.endpoint.displayName)
                    .font(.caption)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(record.environment.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(record.sentAt, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
    }

    private var statusColor: Color {
        switch record.responseStatus {
        case 200..<300: return .green
        case 400..<500: return .orange
        case 500...: return .red
        default: return .secondary
        }
    }
}

extension Notification.Name {
    public static let peelEditApp = Notification.Name("io.galva.peel.editApp")
    public static let peelDeleteApp = Notification.Name("io.galva.peel.deleteApp")
    public static let peelReplayHistory = Notification.Name("io.galva.peel.replayHistory")
    public static let peelOpenCompare = Notification.Name("io.galva.peel.openCompare")
    public static let peelOpenSettings = Notification.Name("io.galva.peel.openSettings")
    public static let peelFocusSearch = Notification.Name("io.galva.peel.focusSearch")
    public static let peelMarkCompare = Notification.Name("io.galva.peel.markCompare")
    public static let peelToggleSidebar = Notification.Name("io.galva.peel.toggleSidebar")
    public static let peelToggleEnv = Notification.Name("io.galva.peel.toggleEnv")
    public static let peelToggleReadOnly = Notification.Name("io.galva.peel.toggleReadOnly")
    public static let peelSendRequest = Notification.Name("io.galva.peel.sendRequest")
}
