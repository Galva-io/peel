import AppKit
import PeelCore
import PeelPersistence
import PeelUI

/// Process entry point. We do not use SwiftUI's `App` protocol because we need
/// fine-grained AppKit control over windowing and the menu bar. The `@main`
/// type is `@MainActor` so storage bootstrap, delegate construction, and
/// `NSApplication` startup all run on the main actor.
@main
@MainActor
enum PeelApp {
    static func main() {
        let store = makeStore()
        let app = NSApplication.shared
        let delegate = PeelAppDelegate(store: store)
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    private static func makeStore() -> PeelAppStore {
        let storage: Storage
        do {
            storage = try Storage.makeDefault()
        } catch {
            PeelLog.lifecycle.error("Persistent store failed; falling back to in-memory: \(error.localizedDescription, privacy: .public)")
            storage = (try? Storage.makeInMemory()) ?? {
                fatalError("Could not initialize storage: \(error)")
            }()
        }
        return PeelAppStore(storage: storage)
    }
}
