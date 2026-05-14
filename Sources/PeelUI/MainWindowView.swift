import SwiftUI
import AppKit
import PeelCore

/// Three-pane window with a custom top bar and bottom status bar — no
/// `NSToolbar`. The title bar above us is the standard macOS one
/// (traffic lights + the title/subtitle we set via `WindowTitleBinder`),
/// so the only "chrome" we render is opaque and document-shaped.
///
///     ┌─────────────────────────────────────────────────────┐
///     │ ◐  Peel — App · Sandbox      (standard title bar)   │
///     ├─────────────────────────────────────────────────────┤
///     │ [ Sandbox | Production ]   Read-only ◯               │  TopBarView
///     ├──────────┬───────────────────────────────┬──────────┤
///     │ Sidebar  │ Editor + Debug                │ Inspect. │
///     ├──────────┴───────────────────────────────┴──────────┤
///     │ Status bar                                           │
///     └─────────────────────────────────────────────────────┘
public struct MainWindowView: View {
    @Bindable public var store: PeelAppStore

    public init(store: PeelAppStore) { self.store = store }

    public var body: some View {
        VStack(spacing: 0) {
            TopBarView(store: store)

            HSplitView {
                SidebarView(store: store)
                    .frame(minWidth: 220, idealWidth: 260, maxWidth: 400, maxHeight: .infinity)

                MainContent(store: store)
                    .frame(minWidth: 480, maxHeight: .infinity)

                if let selection = store.sidebarSelection, store.activeApp != nil {
                    InspectorView(store: store, selection: selection)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)

            StatusBarView(store: store)
        }
        .background(WindowTitleBinder(title: titleText, subtitle: subtitleText))
    }

    private var titleText: String {
        store.activeApp?.displayName ?? "Peel"
    }

    private var subtitleText: String {
        guard let app = store.activeApp else { return "" }
        return "\(app.bundleId) · \(store.environment.displayName)"
    }
}

/// Writes the active app + environment into the host `NSWindow`'s title
/// and subtitle so the standard macOS title bar carries context. Works
/// without an `NSToolbar` attached — these properties live on the window
/// itself.
private struct WindowTitleBinder: NSViewRepresentable {
    let title: String
    let subtitle: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { apply(to: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView.window) }
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
        if window.title != title { window.title = title }
        if window.subtitle != subtitle { window.subtitle = subtitle }
    }
}
