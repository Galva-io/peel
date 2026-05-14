import SwiftUI
import PeelCore

/// Thin status strip at the bottom of every main window — Xcode's bottom
/// bar (the one that shows "Build Succeeded" + warning/error counts and
/// branch state). Ours surfaces environment, read-only state, webhook
/// listener state, and a passive last-action timestamp.
struct StatusBarView: View {
    @Bindable var store: PeelAppStore

    var body: some View {
        HStack(spacing: 14) {
            environmentChip
            readOnlyChip
            listenerChip
            Spacer()
            historyChip
            lastActionChip
        }
        .padding(.horizontal, 10)
        .frame(height: 22)
        .background(.bar)
        .overlay(alignment: .top) {
            Rectangle().fill(.separator).frame(height: 0.5)
        }
        .font(.system(size: 11))
    }

    private var environmentChip: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(store.environment == .production ? PeelTheme.productionTint : Color.gray.opacity(0.6))
                .frame(width: 6, height: 6)
            Text(store.environment.displayName)
                .foregroundStyle(store.environment == .production ? PeelTheme.productionTint : .secondary)
                .fontWeight(store.environment == .production ? .semibold : .regular)
        }
    }

    private var readOnlyChip: some View {
        HStack(spacing: 4) {
            Image(systemName: store.isReadOnly ? "lock.fill" : "lock.open")
                .imageScale(.small)
                .foregroundStyle(store.isReadOnly ? .secondary : PeelTheme.productionTint)
            Text(store.isReadOnly ? "Read-only" : "Mutating allowed")
                .foregroundStyle(store.isReadOnly ? .secondary : PeelTheme.productionTint)
        }
    }

    @ViewBuilder
    private var listenerChip: some View {
        switch store.listenerState {
        case .stopped:
            EmptyView()
        case .starting:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Listener starting…").foregroundStyle(.secondary)
            }
        case let .running(port):
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("Webhook :\(port)").foregroundStyle(.secondary)
            }
        case let .failed(message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .imageScale(.small)
                    .foregroundStyle(PeelTheme.productionTint)
                Text(message)
                    .foregroundStyle(PeelTheme.productionTint)
                    .lineLimit(1)
            }
        }
    }

    private var historyChip: some View {
        Text("\(store.history.count) request\(store.history.count == 1 ? "" : "s")")
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private var lastActionChip: some View {
        if let last = store.lastAction {
            Text(last, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                .foregroundStyle(.tertiary)
        }
    }
}
