import SwiftUI
import PeelCore
import PeelAPI

/// Center pane — the "editor" + "debug" split, mapped directly to Xcode's
/// vertical editor/console layout. The top pane is the request form
/// (the editor); the bottom pane is the response viewer (the debug area).
/// Above them sits the editor tab bar with jump-bar breadcrumb.
public struct MainContent: View {
    @Bindable public var store: PeelAppStore

    public init(store: PeelAppStore) { self.store = store }

    public var body: some View {
        Group {
            if let selection = store.sidebarSelection, store.activeApp != nil {
                editor(for: selection)
            } else {
                EmptyStatePanel(hasApps: !store.apps.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func editor(for selection: SidebarSelection) -> some View {
        VStack(spacing: 0) {
            EditorTabBar(store: store, endpoint: selection.endpoint)
            VSplitView {
                RequestPanel(store: store, selection: selection)
                    .frame(minHeight: 220, idealHeight: 320)

                ResponseViewer(store: store, selection: selection)
                    .frame(minHeight: 180)
            }
        }
    }
}

/// Empty-state when no app/endpoint is selected. Centered mark, single CTA,
/// help popover behind a "?" — same as before, kept brief.
struct EmptyStatePanel: View {
    let hasApps: Bool
    @State private var showingTips = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 14) {
                Spacer(minLength: 24)
                mark
                Text(headline)
                    .font(.title2.weight(.semibold))
                Text(blurb)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                Button {
                    NotificationCenter.default.post(name: .peelAddAppRequested, object: nil)
                } label: {
                    Text(hasApps ? "Add Another App" : "Add an App")
                        .frame(minWidth: 120)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .padding(.top, 4)
                Spacer(minLength: 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                showingTips.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
                    .imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .padding(12)
            .help("Keyboard shortcuts")
            .popover(isPresented: $showingTips, arrowEdge: .top) {
                TipsPopover()
            }
        }
        .background(.background)
    }

    private var mark: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.accentColor.gradient)
            .frame(width: 76, height: 76)
            .overlay(
                Text("P")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
            )
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }

    private var headline: String { hasApps ? "Pick an endpoint" : "Welcome to Peel" }

    private var blurb: String {
        hasApps
            ? "Choose an endpoint under one of your apps in the sidebar."
            : "A workbench for Apple's App Store Server API. Add an app to start."
    }
}

private struct TipsPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("⌘↩", "Send the current request")
            row("⌘⌃E", "Toggle Sandbox / Production")
            row("⌘⌃R", "Toggle read-only mode")
            row("⌘⇧M", "Mark a response for compare")
            row("⌥-click", "Copy a value in the decoded view")
        }
        .padding(14)
        .frame(width: 280)
    }

    private func row(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 10) {
            Text(keys)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .frame(minWidth: 54, alignment: .leading)
            Text(label).font(.callout).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}
