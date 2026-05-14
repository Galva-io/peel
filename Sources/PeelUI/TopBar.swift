import SwiftUI
import PeelCore

/// A plain, opaque strip that sits between the window's title bar and the
/// content. Replaces the previous `.toolbar { … }` so we don't ride on the
/// translucent "liquid glass" `NSToolbar` material — we want something that
/// reads as part of the document chrome rather than its own floating
/// surface. The bar carries the two switches a user changes mid-session:
/// Sandbox/Production and Read-only.
struct TopBarView: View {
    @Bindable var store: PeelAppStore

    var body: some View {
        HStack(spacing: 14) {
            EnvironmentSegment(store: store)
            ReadOnlyToggle(store: store)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.separator).frame(height: 0.5)
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
        .frame(maxWidth: 220)
        .tint(store.environment == .production ? PeelTheme.productionTint : Color.accentColor)
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
