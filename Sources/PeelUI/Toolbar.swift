import SwiftUI
import PeelCore

/// Top of every main window. After the sidebar revamp the active app lives
/// in the sidebar selection, so the toolbar's job shrinks to environment
/// toggle, read-only switch, and a passive timestamp.
public struct PeelToolbar: ToolbarContent {
    @Bindable public var store: PeelAppStore

    public init(store: PeelAppStore) { self.store = store }

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            EnvironmentSegment(store: store)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            ReadOnlyToggle(store: store)
        }
    }
}

struct EnvironmentSegment: View {
    @Bindable var store: PeelAppStore

    var body: some View {
        Picker("Environment", selection: $store.environment) {
            ForEach(APIEnvironment.allCases) { env in
                Text(env.displayName).tag(env)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 240)
        .tint(store.environment == .production ? PeelTheme.productionTint : PeelTheme.sandboxTint)
        .help("Sandbox / Production. ⌘⌃E to toggle.")
    }
}

struct ReadOnlyToggle: View {
    @Bindable var store: PeelAppStore

    var body: some View {
        Toggle("Read-only", isOn: $store.isReadOnly)
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Disable mutating endpoints (⌘⌃R)")
            .tint(store.isReadOnly ? .secondary : PeelTheme.productionTint)
    }
}
