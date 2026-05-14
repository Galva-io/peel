import SwiftUI
import PeelCore
import PeelAPI
import PeelPersistence

/// Two-level sidebar: each app is a collapsible header; each endpoint under
/// it is a selectable row. Only one app's endpoint is focused at a time —
/// clicking an endpoint anywhere makes its parent app the active one.
///
/// We intentionally drop the "Recent history" section here. History is
/// reachable via the View menu and the Compare panel, but the sidebar's job
/// is navigation, not memory.
public struct SidebarView: View {
    @Bindable public var store: PeelAppStore
    @State private var showingAddApp = false
    @State private var appPendingDelete: AppConfig?

    public init(store: PeelAppStore) { self.store = store }

    public var body: some View {
        List(selection: selectionBinding) {
            ForEach(store.apps) { app in
                appSection(app)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 240)
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
        .sheet(isPresented: $showingAddApp) {
            AddAppSheet(store: store, isPresented: $showingAddApp)
        }
        .alert(item: $appPendingDelete) { app in
            Alert(
                title: Text("Delete \(app.displayName)?"),
                message: Text("This removes the app config and its .p8 key from Keychain. History stays intact."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { try? await store.deleteApp(app.id) }
                },
                secondaryButton: .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .peelAddAppRequested)) { _ in
            showingAddApp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .peelDeleteApp)) { note in
            guard let id = note.object as? UUID,
                  let app = store.apps.first(where: { $0.id == id }) else { return }
            appPendingDelete = app
        }
    }

    private var selectionBinding: Binding<SidebarSelection?> {
        Binding(
            get: { store.sidebarSelection },
            set: { newValue in
                guard let newValue else { return }
                store.select(appId: newValue.appId, endpoint: newValue.endpoint)
            }
        )
    }

    @ViewBuilder
    private func appSection(_ app: AppConfig) -> some View {
        let isExpanded = store.expandedAppIds.contains(app.id)
        let isActiveApp = store.activeAppId == app.id

        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { _ in store.toggleExpansion(for: app.id) }
            )
        ) {
            // Flat endpoint list — categories used to nest these but the
            // colored method badge already communicates the read/write split.
            ForEach(EndpointID.allCases, id: \.self) { endpoint in
                EndpointRow(endpoint: endpoint)
                    .tag(SidebarSelection(appId: app.id, endpoint: endpoint))
            }
        } label: {
            AppRow(app: app, isActive: isActiveApp)
                .contextMenu {
                    Button("Edit App Settings…") {
                        NotificationCenter.default.post(name: .peelEditApp, object: app.id)
                    }
                    Button("Refresh icon from App Store") {
                        Task { await store.refreshIcon(for: app.id) }
                    }
                    Button(app.isPinned ? "Unpin" : "Pin") {
                        var updated = app
                        updated.isPinned.toggle()
                        Task { try? await store.updateApp(updated) }
                    }
                    Divider()
                    Button("Delete…", role: .destructive) {
                        appPendingDelete = app
                    }
                }
        }
    }

    private var sidebarFooter: some View {
        HStack {
            Button {
                showingAddApp = true
            } label: {
                Label("Add App", systemImage: "plus.circle")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .help("Add a new App Store Connect app context")

            Spacer()

            if let last = store.lastAction {
                Text(last, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .help("Last API call")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

struct AppRow: View {
    let app: AppConfig
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            AppIconView(app: app, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(app.displayName)
                        .font(.callout.weight(isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.85))
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
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .accessibilityLabel("App \(app.displayName), bundle \(app.bundleId)")
    }
}

struct EndpointRow: View {
    let endpoint: EndpointID

    var body: some View {
        HStack(spacing: 8) {
            MethodBadge(method: endpoint.httpMethod, isDestructive: endpoint.isMutating)
            Text(endpoint.displayName)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }
}

/// HTTP-method chip: `GET` is green, non-mutating `POST` is blue, anything
/// destructive — `PUT` or a mutating `POST` — is the warning color. Same
/// color/text vocabulary as Postman, so devs translate at a glance.
struct MethodBadge: View {
    let method: EndpointID.HTTPMethod
    let isDestructive: Bool

    var body: some View {
        Text(method.label)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(.white)
            .frame(width: 38, height: 16)
            .background(background, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .accessibilityLabel("\(method.label)\(isDestructive ? " · destructive" : "")")
    }

    private var background: Color {
        if isDestructive { return PeelTheme.productionTint }
        switch method {
        case .get: return Color(red: 0.22, green: 0.65, blue: 0.36)   // green
        case .post: return Color(red: 0.30, green: 0.55, blue: 0.95)  // blue
        case .put: return PeelTheme.productionTint                    // warning fallback
        }
    }
}

/// Renders the cached App Store artwork if present, otherwise a colored
/// initial. Same component used in the sidebar, toolbar (vestigial), and
/// add-app sheet so everything stays visually consistent.
public struct AppIconView: View {
    public let app: AppConfig
    public let size: CGFloat

    public init(app: AppConfig, size: CGFloat = 22) {
        self.app = app
        self.size = size
    }

    public var body: some View {
        Group {
            if let data = app.iconData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(Color(hex: app.accentColorHex) ?? .accentColor)
            .overlay(
                Text(String(app.displayName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.55, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            )
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
    public static let peelAddAppRequested = Notification.Name("io.galva.peel.addAppRequested")
}
