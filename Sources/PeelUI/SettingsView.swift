import SwiftUI
import PeelCore

/// Six tabs, in the shape macOS Settings windows usually take:
///   General · Apps · Webhooks · Privacy · Updates · About.
///
/// What used to live in dedicated tabs (Security, Telemetry, History, and
/// Keyboard shortcuts) now folds into either General or Privacy — those
/// surfaces are short enough that splitting them into separate tabs was
/// just bookkeeping.
public struct SettingsView: View {
    @Bindable public var store: PeelAppStore
    @AppStorage("io.galva.peel.menuBarIconMode") private var menuBarIconMode: String = "always"
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
            apps.tabItem { Label("Apps", systemImage: "square.stack.3d.up") }
            privacy.tabItem { Label("Privacy", systemImage: "hand.raised") }
            updates.tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
            about.tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 420)
    }

    // MARK: - General

    private var general: some View {
        Form {
            Section {
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
                Toggle("Read-only by default in new windows", isOn: $readOnlyDefault)
            }
            Section("Keyboard shortcuts") {
                shortcutRow("⌘↩", "Send the current request")
                shortcutRow("⌘⌃E", "Toggle Sandbox / Production")
                shortcutRow("⌘⌃R", "Toggle read-only mode")
                shortcutRow("⌘⇧M", "Mark a response for compare")
                shortcutRow("⌘⇧N", "Add an app")
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    private func shortcutRow(_ keys: String, _ label: String) -> some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            Text(keys)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: - Apps

    private var apps: some View {
        VStack(alignment: .leading) {
            Text("Configured apps").font(.headline)
            if store.apps.isEmpty {
                Text("No apps yet. Add one from the sidebar or with ⌘⇧N.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                List(store.apps) { app in
                    HStack(spacing: 10) {
                        AppIconView(app: app, size: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.displayName)
                            Text(app.bundleId).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(app.environmentSupport == .both ? "Sandbox + Prod"
                             : app.environmentSupport == .sandboxOnly ? "Sandbox only" : "Production only")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Delete", role: .destructive) {
                            Task { try? await store.deleteApp(app.id) }
                        }
                        .controlSize(.small)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
    }

    // MARK: - Privacy

    private var privacy: some View {
        Form {
            Section {
                Stepper("Retain history for \(historyRetentionDays) days",
                        value: $historyRetentionDays, in: 1...3650)
                Button("Clear all history…", role: .destructive) {
                    Task {
                        try? await store.storage.purgeHistoryOlderThan(.distantFuture)
                        await store.reloadHistory()
                    }
                }
                Button("Export audit log as JSONL…") {
                    Task { await exportAudit() }
                }
            } header: {
                Text("History")
            } footer: {
                Text("History and the audit log are local-only and never leave your Mac.")
            }

            Section {
                Toggle("Send anonymous endpoint-usage counts", isOn: $telemetryEnabled)
                Link("Privacy policy", destination: URL(string: "https://peel-app.com/privacy")!)
                Button("Reset Keychain access…", role: .destructive) {
                    try? store.keychain.purgeAll()
                }
            } header: {
                Text("Privacy & Security")
            } footer: {
                Text("Telemetry is off by default. When on, Peel sends counts only — never bodies, transaction IDs, or app names.")
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    // MARK: - Updates

    private var updates: some View {
        Form {
            Section {
                Toggle("Receive beta builds", isOn: $betaChannel)
                Button("Check for updates now") { /* Sparkle hook */ }
            } footer: {
                Text("Peel checks update.peel-app.com via Sparkle. Updates are signed with Galva's Developer ID.")
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    // MARK: - About

    private var about: some View {
        VStack(spacing: 8) {
            Spacer()
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.gradient)
                .frame(width: 64, height: 64)
                .overlay(Text("P").font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundStyle(.white))
            Text("Peel").font(.title2.weight(.semibold))
            Text("App Store Server API workbench").font(.callout).foregroundStyle(.secondary)
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0-dev")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 14) {
                Link("peel-app.com", destination: URL(string: "https://peel-app.com")!)
                Link("GitHub", destination: URL(string: "https://github.com/galva/peel")!)
                Link("Privacy", destination: URL(string: "https://peel-app.com/privacy")!)
            }
            .font(.callout)
        }
        .multilineTextAlignment(.center)
        .padding(20)
    }

    /// `NSSavePanel` is `@MainActor`-isolated in Swift 6, so the whole
    /// function lives on the main actor — the storage hop already uses
    /// `await`, no extra Task hopping needed.
    @MainActor
    private func exportAudit() async {
        let jsonl = (try? await store.storage.exportAuditJSONL()) ?? ""
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "peel-audit.jsonl"
        if panel.runModal() == .OK, let url = panel.url {
            try? jsonl.data(using: .utf8)?.write(to: url)
        }
    }
}
