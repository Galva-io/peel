import SwiftUI
import PeelCore

public struct MainWindowView: View {
    @Bindable public var store: PeelAppStore

    public init(store: PeelAppStore) { self.store = store }

    public var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } detail: {
            MainContent(store: store)
                .navigationTitle("Peel")
        }
        .toolbar { PeelToolbar(store: store) }
        .background(
            store.environment == .production
                ? PeelTheme.productionTint.opacity(0.08)
                : Color.clear
        )
    }
}
