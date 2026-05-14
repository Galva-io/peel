import AppKit
import SwiftUI
import PeelUI

/// Persistent menu bar icon. Click reveals the quick-lookup popover. Mode is
/// configurable: always show, on-demand, off.
@MainActor
final class MenuBarController {
    private let store: PeelAppStore
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    init(store: PeelAppStore) {
        self.store = store
    }

    func refresh() {
        let mode = UserDefaults.standard.string(forKey: "io.galva.peel.menuBarIconMode") ?? "always"
        switch mode {
        case "off":
            teardown()
        default:
            installIfNeeded()
        }
    }

    private func installIfNeeded() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "drop.degreesign", accessibilityDescription: "Peel")
            button.action = #selector(toggle(_:))
            button.target = self
        }
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 360)
        popover.contentViewController = NSHostingController(rootView: MenuBarPopover(store: store))
        self.popover = popover
    }

    private func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        popover = nil
    }

    @objc private func toggle(_ sender: Any?) {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
