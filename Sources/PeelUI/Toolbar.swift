import SwiftUI
import PeelCore

/// Top of every main window. Apps picker, environment toggle, read-only
/// switch, last-action timestamp.
public struct PeelToolbar: ToolbarContent {
    @Bindable public var store: PeelAppStore

    public init(store: PeelAppStore) { self.store = store }

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            HStack(spacing: 12) {
                AppPicker(store: store)
                EnvironmentToggle(store: store)
                ReadOnlyToggle(store: store)
                Spacer()
                if let lastAction = store.lastAction {
                    Text("Last action \(lastAction, format: .relative(presentation: .numeric, unitsStyle: .narrow))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct AppPicker: View {
    @Bindable var store: PeelAppStore

    var body: some View {
        Menu {
            ForEach(store.apps) { app in
                Button {
                    store.activeAppId = app.id
                } label: {
                    HStack {
                        Text(app.displayName)
                        if store.activeAppId == app.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            if store.apps.isEmpty {
                Text("No apps configured")
            }
        } label: {
            HStack(spacing: 6) {
                if let app = store.activeApp {
                    Circle()
                        .fill(Color(hex: app.accentColorHex) ?? .accentColor)
                        .frame(width: 8, height: 8)
                    Text(app.displayName)
                } else {
                    Text("No app selected")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .menuStyle(.borderlessButton)
    }
}

struct EnvironmentToggle: View {
    @Bindable var store: PeelAppStore

    var body: some View {
        Picker("Environment", selection: $store.environment) {
            ForEach(APIEnvironment.allCases) { env in
                HStack {
                    Circle().fill(env == .production ? PeelTheme.productionTint : PeelTheme.sandboxTint)
                        .frame(width: 8, height: 8)
                    Text(env.displayName)
                }
                .tag(env)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 220)
        .tint(store.environment == .production ? PeelTheme.productionTint : .accentColor)
        .help("Sandbox / Production toggle. Production calls require confirmation.")
    }
}

struct ReadOnlyToggle: View {
    @Bindable var store: PeelAppStore

    var body: some View {
        Toggle(isOn: $store.isReadOnly) {
            Label(store.isReadOnly ? "Read-only" : "Mutating allowed",
                  systemImage: store.isReadOnly ? "lock.fill" : "lock.open")
        }
        .toggleStyle(.button)
        .controlSize(.regular)
        .help("Disable mutating endpoints (⌘⌃R)")
        .tint(store.isReadOnly ? .secondary : PeelTheme.productionTint)
    }
}
