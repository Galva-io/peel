import AppKit
import SwiftUI
import PeelCore
import PeelUI

@MainActor
final class PeelAppDelegate: NSObject, NSApplicationDelegate {
    let store: PeelAppStore
    private var windowControllers: [PeelMainWindowController] = []
    private var settingsWindowController: NSWindowController?
    private var aboutWindowController: NSWindowController?
    private var compareWindowController: NSWindowController?
    private var menuBarController: MenuBarController?

    init(store: PeelAppStore) {
        self.store = store
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        Task {
            await store.bootstrap()
            if UserDefaults.standard.bool(forKey: "io.galva.peel.webhookAutoStart") {
                await store.startWebhookListener()
            }
        }
        openMainWindow()
        menuBarController = MenuBarController(store: store)
        menuBarController?.refresh()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openMainWindow() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func openMainWindow() {
        let controller = PeelMainWindowController(store: store)
        windowControllers.append(controller)
        controller.showWindow(nil)
    }

    func openSettings() {
        if let existing = settingsWindowController {
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: SettingsView(store: store))
        window.isReleasedWhenClosed = false
        window.center()
        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
    }

    func openAbout() {
        if let existing = aboutWindowController {
            existing.showWindow(nil)
            return
        }
        let view = AboutView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Peel"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.center()
        let controller = NSWindowController(window: window)
        aboutWindowController = controller
        controller.showWindow(nil)
    }

    func openCompare() {
        if let existing = compareWindowController {
            existing.showWindow(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Compare Responses"
        window.contentView = NSHostingView(rootView: ComparePanel(store: store))
        window.isReleasedWhenClosed = false
        window.center()
        let controller = NSWindowController(window: window)
        compareWindowController = controller
        controller.showWindow(nil)
    }
}
