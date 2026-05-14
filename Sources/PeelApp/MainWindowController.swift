import AppKit
import SwiftUI
import PeelCore
import PeelUI

/// One controller per main window. Owns the AppKit shell and embeds the
/// SwiftUI content via `NSHostingController`. We use AppKit for window
/// management — multiple windows, tabs, services, drag-drop — because SwiftUI
/// on macOS still loses behavior at the window-management level.
@MainActor
final class PeelMainWindowController: NSWindowController, NSWindowDelegate {
    private let store: PeelAppStore

    init(store: PeelAppStore) {
        self.store = store
        // No `.fullSizeContentView` / `toolbarStyle` — we no longer use an
        // `NSToolbar`. The window is just title bar + content, and the
        // SwiftUI `TopBarView` paints its own opaque strip below the title.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Peel"
        window.titlebarAppearsTransparent = false
        window.tabbingMode = .preferred
        window.minSize = NSSize(width: 880, height: 560)
        window.setFrameAutosaveName("PeelMainWindow")
        window.center()

        super.init(window: window)
        window.delegate = self

        let hosting = NSHostingController(rootView: MainWindowView(store: store))
        window.contentViewController = hosting
        window.identifier = NSUserInterfaceItemIdentifier("peel.main")

        // Register for handoff/continuation. Real continuation activity types
        // are added as features ship (e.g. transaction lookups).
        window.collectionBehavior.insert(.fullScreenPrimary)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func windowWillClose(_ notification: Notification) {
        // Default macOS behavior: app keeps running with no windows; the dock
        // icon reopens a new one. This matches Mail, Notes, etc.
    }
}
