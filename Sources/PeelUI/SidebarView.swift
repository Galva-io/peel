import SwiftUI
import PeelCore
import PeelAPI
import PeelPersistence

/// Project-Navigator-style sidebar. The patterns borrowed from Xcode are:
///
///   • A vibrant source-list (`.listStyle(.sidebar)`) so the pane picks up
///     the window's translucency in both light and dark appearances.
///   • Tight 11-pt typography for endpoint rows, 12-pt for the app row
///     that frames them. The weight differential is what distinguishes
///     "container" from "leaf" — no boxes, no badges.
///   • A bottom filter strip that fades into the sidebar material with a
///     filter glyph that lights up when filtering is active.
///   • `controlSize(.small)` everywhere so disclosure triangles, row
///     heights, and chevrons match navigator density.
///
/// Every color used here comes from the system semantic palette, so the
/// pane reads identically in either appearance — no per-mode overrides
/// needed.
public struct SidebarView: View {
    @Bindable public var store: PeelAppStore
    @State private var showingAddApp = false
    @State private var appPendingDelete: AppConfig?
    @State private var filterText: String = ""

    public init(store: PeelAppStore) { self.store = store }

    public var body: some View {
        VStack(spacing: 0) {
            List(selection: selectionBinding) {
                ForEach(visibleApps) { app in
                    appSection(app)
                }
            }
            .listStyle(.sidebar)
            .controlSize(.small)
            .scrollContentBackground(.hidden)

            filterBar
        }
        .frame(minWidth: 220)
        .background(.regularMaterial)
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

    // MARK: - Filter

    private var visibleApps: [AppConfig] {
        let needle = filterText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return store.apps }
        return store.apps.filter { app in
            if app.displayName.lowercased().contains(needle) { return true }
            if app.bundleId.lowercased().contains(needle) { return true }
            return EndpointID.allCases.contains { $0.displayName.lowercased().contains(needle) }
        }
    }

    private func matchesFilter(_ endpoint: EndpointID, in app: AppConfig) -> Bool {
        let needle = filterText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return true }
        if app.displayName.lowercased().contains(needle) || app.bundleId.lowercased().contains(needle) {
            return true
        }
        return endpoint.displayName.lowercased().contains(needle)
    }

    // MARK: - Rows

    @ViewBuilder
    private func appSection(_ app: AppConfig) -> some View {
        let needle = filterText.trimmingCharacters(in: .whitespaces).lowercased()
        let userExpanded = store.expandedAppIds.contains(app.id)
        let forceExpanded = !needle.isEmpty
        let isExpanded = forceExpanded || userExpanded
        let isActiveApp = store.activeAppId == app.id

        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { _ in
                    if !forceExpanded { store.toggleExpansion(for: app.id) }
                }
            )
        ) {
            ForEach(EndpointID.allCases.filter { matchesFilter($0, in: app) }, id: \.self) { endpoint in
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

    // MARK: - Filter bar

    /// Sits at the foot of every Xcode navigator. Same idiom here:
    ///
    ///     ⌕ Filter [×]                 │ +
    ///
    /// The filter glyph fills with the system accent color when a filter
    /// is active — a single-pixel state change that's easy to miss but
    /// matters for "is my list filtered right now?"
    private var filterBar: some View {
        HStack(spacing: 6) {
            Image(systemName: filterText.isEmpty
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
                .imageScale(.small)
                .foregroundStyle(filterText.isEmpty ? AnyShapeStyle(HierarchicalShapeStyle.secondary) : AnyShapeStyle(Color.accentColor))

            TextField("Filter", text: $filterText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .frame(minHeight: 16)

            if !filterText.isEmpty {
                Button { filterText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.small)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
            }

            Divider()
                .frame(height: 12)

            Button {
                showingAddApp = true
            } label: {
                Image(systemName: "plus")
                    .imageScale(.small)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help("Add an app context (⌘⇧N)")
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
        .overlay(alignment: .top) {
            Rectangle().fill(.separator).frame(height: 0.5)
        }
    }
}

/// App "container" row. Slightly heavier than endpoint rows — 12-pt body
/// weight when active, regular when idle — so the eye reads the app as the
/// parent and endpoints as its children even without explicit nesting
/// lines.
struct AppRow: View {
    let app: AppConfig
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            AppIconView(app: app, size: 16)
            Text(app.displayName)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
            if app.isPinned {
                Image(systemName: "pin.fill")
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityLabel("App \(app.displayName), bundle \(app.bundleId)")
    }
}

/// Endpoint "leaf" row. 11-pt body, tertiary-tinted glyph, no chrome —
/// typography carries the row. Destructive endpoints (PUT or mutating
/// POST) tint their glyph with the warning color so the eye catches them.
struct EndpointRow: View {
    let endpoint: EndpointID

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: glyph)
                .imageScale(.small)
                .frame(width: 12)
                .foregroundStyle(endpoint.isMutating ? AnyShapeStyle(PeelTheme.productionTint) : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
                .accessibilityHidden(true)
            Text(endpoint.displayName)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .accessibilityLabel("\(endpoint.displayName)\(endpoint.isMutating ? ", destructive" : "")")
    }

    private var glyph: String {
        switch endpoint.httpMethod {
        case .get: return "arrow.down.circle"
        case .post: return "paperplane"
        case .put: return "pencil"
        }
    }
}

/// Renders cached App Store artwork when available, otherwise a colored
/// initial. Shared by the sidebar, the add-app preview, and the inspector.
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
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
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
    public static let peelToggleEnv = Notification.Name("io.galva.peel.toggleEnv")
    public static let peelToggleReadOnly = Notification.Name("io.galva.peel.toggleReadOnly")
    public static let peelSendRequest = Notification.Name("io.galva.peel.sendRequest")
    public static let peelAddAppRequested = Notification.Name("io.galva.peel.addAppRequested")
}
