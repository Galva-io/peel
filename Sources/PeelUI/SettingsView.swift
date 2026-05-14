import SwiftUI
import PeelCore

public struct SettingsView: View {
    @Bindable public var store: PeelAppStore
    @AppStorage("io.galva.peel.menuBarIconMode") private var menuBarIconMode: String = "always"
    @AppStorage("io.galva.peel.webhookPort") private var webhookPort: Int = 9876
    @AppStorage("io.galva.peel.webhookAutoStart") private var webhookAutoStart: Bool = false
    @AppStorage("io.galva.peel.historyRetentionDays") private var historyRetentionDays: Int = 30
    @AppStorage("io.galva.peel.telemetryEnabled") private var telemetryEnabled: Bool = false
    @AppStorage("io.galva.peel.theme") private var theme: String = "system"
    @AppStorage("io.galva.peel.soundsEnabled") private var soundsEnabled: Bool = false
    @AppStorage("io.galva.peel.readOnlyDefault") private var readOnlyDefault: Bool = true
    @AppStorage("io.galva.peel.betaChannel") private var betaChannel: Bool = false

    public init(store: PeelAppStore) { self.store = store }

    public var body: some View {
        TabView {
            general.tabItem { Label("General", systemImage: "gear") }
            apps.tabItem { Label("Apps", systemImage: "app.badge") }
            security.tabItem { Label("Security", systemImage: "lock.shield") }
            webhook.tabItem { Label("Webhooks", systemImage: "antenna.radiowaves.left.and.right") }
            history.tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            updates.tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
            telemetry.tabItem { Label("Telemetry", systemImage: "chart.bar.xaxis") }
            shortcuts.tabItem { Label("Keyboard", systemImage: "keyboard") }
            about.tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 420)
    }

    private var general: some View {
        Form {
            Picker("Theme", selection: $theme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            Picker("Menu bar icon", selection: $menuBarIconMode) {
                Text("Always show").tag("always")
                Text("On demand").tag("ondemand")
                Text("Off").tag("off")
            }
            Toggle("Sound effects", isOn: $soundsEnabled)
        }
        .padding(20)
    }

    private var apps: some View {
        VStack(alignment: .leading) {
            Text("Configured apps").font(.headline)
            List(store.apps) { app in
                HStack {
                    Image(systemName: "app.dashed")
                    VStack(alignment: .leading) {
                        Text(app.displayName)
                        Text(app.bundleId).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(app.environmentSupport.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Delete…", role: .destructive) {
                        Task { try? await store.deleteApp(app.id) }
                    }
                }
            }
        }
        .padding(20)
    }

    private var security: some View {
        Form {
            Toggle("Default new windows to read-only", isOn: $readOnlyDefault)
            Stepper("History retention: \(historyRetentionDays) days",
                    value: $historyRetentionDays, in: 1...3650)
            Section {
                Text("Keys are stored in the macOS Keychain with `AccessibleAfterFirstUnlockThisDeviceOnly` and are never synced to iCloud.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Reset Keychain access…", role: .destructive) {
                    try? store.keychain.purgeAll()
                }
            }
        }
        .padding(20)
    }

    private var webhook: some View {
        Form {
            Stepper("Listener port: \(webhookPort)", value: $webhookPort, in: 1024...65535)
            Toggle("Start listener at app launch", isOn: $webhookAutoStart)
            HStack {
                switch store.listenerState {
                case .stopped: Label("Stopped", systemImage: "stop.circle").foregroundStyle(.secondary)
                case .starting: Label("Starting…", systemImage: "circle.dotted")
                case let .running(port): Label("Listening on \(port)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case let .failed(msg): Label(msg, systemImage: "exclamationmark.octagon.fill").foregroundStyle(PeelTheme.productionTint)
                }
                Spacer()
                Button("Start") { Task { await store.startWebhookListener() } }
                Button("Stop") { Task { await store.stopWebhookListener() } }
            }
            Text("Receiver is bound to 127.0.0.1 only.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History").font(.headline)
            Stepper("Retain for \(historyRetentionDays) days", value: $historyRetentionDays, in: 1...3650)
            Button("Clear all history…", role: .destructive) {
                Task {
                    try? await store.storage.purgeHistoryOlderThan(.distantFuture)
                    await store.reloadHistory()
                }
            }
            Button("Export audit log as JSONL…") {
                Task { await exportAudit() }
            }
        }
        .padding(20)
    }

    private var updates: some View {
        Form {
            Toggle("Receive beta builds", isOn: $betaChannel)
            Text("Peel checks update.peel-app.com for new releases via Sparkle. Updates are signed with Galva's Developer ID.")
                .font(.callout).foregroundStyle(.secondary)
            Button("Check for updates now") { /* Sparkle hook — see PeelApp */ }
        }
        .padding(20)
    }

    private var telemetry: some View {
        Form {
            Toggle("Send anonymous endpoint-usage counts", isOn: $telemetryEnabled)
            Text("Counts only — never request bodies, transaction IDs, or any user data. Transmitted to telemetry.peel-app.com. Off by default.")
                .font(.callout).foregroundStyle(.secondary)
            Link("Privacy policy", destination: URL(string: "https://peel-app.com/privacy")!)
        }
        .padding(20)
    }

    private var shortcuts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                shortcutRow("⌘N", "New window")
                shortcutRow("⌘T", "New tab")
                shortcutRow("⌘,", "Settings")
                shortcutRow("⌘↩", "Send request")
                shortcutRow("⌘⇧M", "Mark response for compare")
                shortcutRow("⌘⌃E", "Toggle environment")
                shortcutRow("⌘⌃R", "Toggle read-only mode")
                shortcutRow("⌘1…⌘9", "Switch active app")
                shortcutRow("⌘\\", "Toggle sidebar")
                shortcutRow("⌘Y", "Show history")
            }
            .padding(20)
        }
    }

    private var about: some View {
        VStack(spacing: 6) {
            Image(systemName: "apple.logo").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Peel").font(.title.weight(.semibold))
            Text("App Store Server API workbench").font(.callout).foregroundStyle(.secondary)
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0-dev")
                .font(.caption).foregroundStyle(.secondary)
            Divider().padding(.vertical, 8)
            Text("By the team behind Habitify.").font(.callout)
            Link("peel-app.com", destination: URL(string: "https://peel-app.com")!)
            Link("Source on GitHub", destination: URL(string: "https://github.com/galva/peel")!)
        }
        .multilineTextAlignment(.center)
        .padding(20)
    }

    private func shortcutRow(_ keys: String, _ label: String) -> some View {
        HStack {
            Text(keys).font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text(label).font(.callout)
            Spacer()
        }
    }

    private func exportAudit() async {
        let jsonl = (try? await store.storage.exportAuditJSONL()) ?? ""
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "peel-audit.jsonl"
        if panel.runModal() == .OK, let url = panel.url {
            try? jsonl.data(using: .utf8)?.write(to: url)
        }
    }
}
