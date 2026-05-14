import AppKit
import PeelCore
import PeelUI

/// Hand-built main menu. We could use SwiftUI's `Scene.commands`, but going
/// AppKit-direct here is simpler and avoids the menu re-creation issues that
/// crop up when you mix SwiftUI menus with multi-window AppKit shells.
@MainActor
extension PeelAppDelegate {
    func installMainMenu() {
        let mainMenu = NSMenu()
        mainMenu.addItem(buildAppMenu())
        mainMenu.addItem(buildFileMenu())
        mainMenu.addItem(buildEditMenu())
        mainMenu.addItem(buildViewMenu())
        mainMenu.addItem(buildEnvironmentMenu())
        mainMenu.addItem(buildWindowMenu())
        mainMenu.addItem(buildHelpMenu())
        NSApp.mainMenu = mainMenu
    }

    private func buildAppMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Peel")
        item.submenu = menu

        let about = NSMenuItem(title: "About Peel", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        services.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        menu.addItem(services)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Hide Peel", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthers)
        menu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Peel", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return item
    }

    private func buildFileMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "File")
        item.submenu = menu

        let new = NSMenuItem(title: "New Window", action: #selector(newWindow), keyEquivalent: "n")
        new.target = self
        menu.addItem(new)

        let newTab = NSMenuItem(title: "New Tab", action: #selector(NSWindow.newWindowForTab(_:)), keyEquivalent: "t")
        menu.addItem(newTab)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))

        return item
    }

    private func buildEditMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Edit")
        item.submenu = menu
        menu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "Select All", action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a"))
        menu.addItem(.separator())
        let find = NSMenuItem(title: "Find in Response", action: #selector(focusSearch), keyEquivalent: "f")
        find.target = self
        menu.addItem(find)
        return item
    }

    private func buildViewMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "View")
        item.submenu = menu

        // No sidebar toggle — the panes are always visible and can be
        // collapsed by dragging the splitter.

        let enterFullScreen = NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        enterFullScreen.keyEquivalentModifierMask = [.command, .control]
        menu.addItem(enterFullScreen)

        return item
    }

    private func buildEnvironmentMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Environment")
        item.submenu = menu

        let toggle = NSMenuItem(title: "Toggle Environment (Sandbox / Production)", action: #selector(toggleEnvironment), keyEquivalent: "e")
        toggle.target = self
        toggle.keyEquivalentModifierMask = [.command, .control]
        menu.addItem(toggle)

        let readOnly = NSMenuItem(title: "Toggle Read-Only Mode", action: #selector(toggleReadOnly), keyEquivalent: "r")
        readOnly.target = self
        readOnly.keyEquivalentModifierMask = [.command, .control]
        menu.addItem(readOnly)

        menu.addItem(.separator())

        let send = NSMenuItem(title: "Send Request", action: #selector(sendRequest), keyEquivalent: "\r")
        send.target = self
        menu.addItem(send)

        let compare = NSMenuItem(title: "Open Compare…", action: #selector(showCompare), keyEquivalent: "d")
        compare.target = self
        compare.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(compare)

        return item
    }

    private func buildWindowMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Window")
        item.submenu = menu
        menu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        NSApp.windowsMenu = menu
        return item
    }

    private func buildHelpMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Help")
        item.submenu = menu

        let docs = NSMenuItem(title: "Peel Documentation", action: #selector(openDocs), keyEquivalent: "?")
        docs.target = self
        menu.addItem(docs)

        let appleDocs = NSMenuItem(title: "App Store Server API on Apple Developer", action: #selector(openAppleDocs), keyEquivalent: "")
        appleDocs.target = self
        menu.addItem(appleDocs)

        let issue = NSMenuItem(title: "Report an Issue on GitHub", action: #selector(openIssues), keyEquivalent: "")
        issue.target = self
        menu.addItem(issue)

        return item
    }

    // MARK: - Menu actions

    @objc private func newWindow() {
        openMainWindow()
    }

    @objc func showAbout() {
        openAbout()
    }

    @objc func showSettings() {
        openSettings()
    }

    @objc func showCompare() {
        openCompare()
    }

    @objc private func toggleEnvironment() {
        let current = store.environment
        let next: PeelCore.APIEnvironment = current == .sandbox ? .production : .sandbox
        if next == .production {
            let alert = NSAlert()
            alert.messageText = "Switch to Production?"
            alert.informativeText = "Production calls hit live customer data. Read-only mode stays on unless you turn it off explicitly."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Switch")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() != .alertFirstButtonReturn { return }
        }
        store.environment = next
    }

    @objc private func toggleReadOnly() {
        if store.isReadOnly == true && store.environment == .production {
            let alert = NSAlert()
            alert.messageText = "Allow mutating requests in Production?"
            alert.informativeText = "You're about to enable mutating endpoints (refunds, extensions) against live customer data."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Allow")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() != .alertFirstButtonReturn { return }
        }
        store.isReadOnly.toggle()
    }

    @objc private func sendRequest() {
        NotificationCenter.default.post(name: .peelSendRequest, object: nil)
    }

    @objc private func focusSearch() {
        NotificationCenter.default.post(name: .peelFocusSearch, object: nil)
    }

    @objc private func openDocs() {
        NSWorkspace.shared.open(URL(string: "https://peel-app.com/docs")!)
    }

    @objc private func openAppleDocs() {
        NSWorkspace.shared.open(URL(string: "https://developer.apple.com/documentation/appstoreserverapi")!)
    }

    @objc private func openIssues() {
        NSWorkspace.shared.open(URL(string: "https://github.com/galva/peel/issues")!)
    }
}
