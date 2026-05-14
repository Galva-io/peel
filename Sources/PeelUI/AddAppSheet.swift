import SwiftUI
import UniformTypeIdentifiers
import PeelCore

/// Add App sheet — Xcode Project Settings layout.
///
///   ┌─────────────────────────────────────────────────┐
///   │                                                 │
///   │   [Icon]   App Name                             │  Identity header
///   │            com.example.app                      │
///   │                                                 │
///   │ ──────────────────────────────────────────────  │
///   │   APP IDENTITY                                  │  Inspector form
///   │           App Store URL  [______]  [Fetch]      │
///   │            Display Name  [______]               │
///   │              Bundle ID  [______]                │
///   │                                                 │
///   │   AUTHENTICATION                                │
///   │              Issuer ID  [______]                │
///   │                Key ID  [______]                 │
///   │            Private Key  [Drop .p8 …]            │
///   │                                                 │
///   │ ──────────────────────────────────────────────  │
///   │                            [Cancel]  [Add]      │
///   └─────────────────────────────────────────────────┘
public struct AddAppSheet: View {
    @Bindable public var store: PeelAppStore
    @Binding public var isPresented: Bool

    @State private var appStoreInput: String = ""
    @State private var displayName = ""
    @State private var bundleId = ""
    @State private var issuerId = ""
    @State private var keyId = ""
    @State private var pemContents: String = ""
    @State private var pemFileName: String?
    @State private var iconData: Data?
    @State private var errorMessage: String?
    @State private var isDropTargeted = false
    @State private var isLookingUp = false
    @State private var lookupTask: Task<Void, Never>?
    @State private var didAttemptSubmit = false

    public init(store: PeelAppStore, isPresented: Binding<Bool>) {
        self.store = store
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            identityHeader
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: InspectorFormMetrics.sectionSpacing) {
                    appIdentitySection
                    authenticationSection
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
            Divider()
            footer
        }
        .frame(width: 560, height: 600)
        .onDisappear { lookupTask?.cancel() }
    }

    // MARK: - Identity header

    private var identityHeader: some View {
        HStack(spacing: 14) {
            AppIconView(app: previewConfig, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName.isEmpty ? "New App" : displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(displayName.isEmpty ? .secondary : .primary)
                Text(bundleId.isEmpty ? "Bundle ID not set" : bundleId)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var previewConfig: AppConfig {
        AppConfig(
            displayName: displayName.isEmpty ? "New App" : displayName,
            bundleId: bundleId,
            issuerId: issuerId,
            keyId: keyId,
            accentColorHex: derivedAccentHex,
            iconData: iconData
        )
    }

    /// Stable deterministic placeholder color from the bundle id so the
    /// sidebar pill is differentiable even when the App Store lookup
    /// doesn't return artwork.
    private var derivedAccentHex: String {
        let seed = bundleId.isEmpty ? displayName : bundleId
        let hash = abs(seed.hashValue)
        let palette = ["#0A84FF", "#5E5CE6", "#BF5AF2", "#FF375F", "#FF9F0A", "#30D158", "#64D2FF"]
        return palette[hash % palette.count]
    }

    // MARK: - App Identity

    private var appIdentitySection: some View {
        InspectorFormSection(title: "App Identity") {
            InspectorFormRow(
                label: "App Store URL",
                help: "Paste an App Store link or bundle id and tap Fetch."
            ) {
                HStack(spacing: 6) {
                    TextField(
                        "",
                        text: $appStoreInput,
                        prompt: Text("https://apps.apple.com/…/id1234567890")
                    )
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onSubmit { triggerLookup() }
                    if isLookingUp {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Fetch") { triggerLookup() }
                            .controlSize(.small)
                            .disabled(appStoreInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }

            InspectorFormRow(label: "Display Name", isRequired: true,
                             error: didAttemptSubmit && displayName.isEmpty ? "Required" : nil) {
                TextField("", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }

            InspectorFormRow(
                label: "Bundle ID",
                isRequired: true,
                error: bundleIdError
            ) {
                TextField("", text: $bundleId, prompt: Text("com.example.app"))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }
        }
    }

    private var bundleIdError: String? {
        if bundleId.isEmpty { return didAttemptSubmit ? "Required" : nil }
        return AppConfigValidator.validateBundleId(bundleId).message
    }

    // MARK: - Authentication

    private var authenticationSection: some View {
        InspectorFormSection(title: "Authentication") {
            InspectorFormRow(
                label: "Issuer ID",
                isRequired: true,
                help: "UUID from App Store Connect → Users and Access → Integrations.",
                error: issuerIdError
            ) {
                TextField("", text: $issuerId, prompt: Text("UUID"))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }

            InspectorFormRow(
                label: "Key ID",
                isRequired: true,
                help: "10 characters; auto-filled when you drop the .p8 below.",
                error: keyIdError
            ) {
                TextField("", text: $keyId, prompt: Text("ABCDEFGHIJ"))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }

            InspectorFormRow(
                label: "Private Key",
                isRequired: true,
                help: pemContents.isEmpty ? "Drag the AuthKey_XXXXXXXXXX.p8 file onto the well." : nil,
                error: didAttemptSubmit && pemContents.isEmpty ? "Required" : nil
            ) {
                keyDropWell
            }
        }
    }

    private var issuerIdError: String? {
        if issuerId.isEmpty { return didAttemptSubmit ? "Required" : nil }
        return AppConfigValidator.validateIssuerId(issuerId).message
    }

    private var keyIdError: String? {
        if keyId.isEmpty { return didAttemptSubmit ? "Required" : nil }
        return AppConfigValidator.validateKeyId(keyId).message
    }

    /// Combined PEM input: a monospaced TextEditor users can paste the .p8
    /// contents into, with a "Choose File…" button beside it for the
    /// classic file picker. Drag-and-drop still works onto the editor.
    private var keyDropWell: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $pemContents)
                    .font(.system(size: 11, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 86, maxHeight: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(isDropTargeted ? Color.accentColor : Color.primary.opacity(0.12),
                                          lineWidth: isDropTargeted ? 1.2 : 0.5)
                    )
                    .onChange(of: pemContents) { _, newValue in
                        // If the user pastes a key by hand we no longer know
                        // which file it came from; drop the filename so we
                        // don't lie about provenance.
                        if pemFileName != nil, !newValue.contains(pemFileName ?? "") {
                            pemFileName = nil
                        }
                    }

                if pemContents.isEmpty {
                    Text(placeholderPEM)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 13)
                        .allowsHitTesting(false)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in await self.loadKey(from: url) }
                }
                return true
            }

            HStack(spacing: 8) {
                Button("Choose File…") { openKeyPanel() }
                    .controlSize(.small)
                if let pemFileName {
                    Text(pemFileName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if !pemContents.isEmpty {
                    Text("\(pemContents.count) characters pasted")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("or drop a .p8 file onto the field above")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
        }
    }

    private var placeholderPEM: String {
        """
        -----BEGIN PRIVATE KEY-----
        Paste the contents of your AuthKey_XXXXXXXXXX.p8 here
        -----END PRIVATE KEY-----
        """
    }

    private func openKeyPanel() {
        let panel = NSOpenPanel()
        panel.title = "Choose your .p8 private key"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        // Allow `.p8` (a dynamic UTI created from the extension) and
        // fall back to plain text so users can pick exported PEM files.
        if let p8 = UTType(filenameExtension: "p8") {
            panel.allowedContentTypes = [p8, .text]
        } else {
            panel.allowedContentTypes = [.text, .data]
        }
        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in await self.loadKey(from: url) }
        }
    }

    // MARK: - Error + footer

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.small)
                .foregroundStyle(PeelTheme.productionTint)
            Text(message)
                .font(.system(size: 11))
            Spacer()
            Button("Dismiss") { errorMessage = nil }
                .buttonStyle(.borderless)
                .controlSize(.small)
        }
        .padding(8)
        .background(PeelTheme.productionTint.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(PeelTheme.productionTint.opacity(0.3))
        )
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { isPresented = false }
                .keyboardShortcut(.cancelAction)
            Button("Add") {
                didAttemptSubmit = true
                Task { await commit() }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    // MARK: - Behavior

    private func triggerLookup() {
        lookupTask?.cancel()
        let raw = appStoreInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        isLookingUp = true
        lookupTask = Task {
            defer { Task { @MainActor in self.isLookingUp = false } }
            do {
                let metadata: AppStoreLookup.AppMetadata
                if AppStoreLookup.extractAppID(from: raw) != nil {
                    metadata = try await store.appStoreLookup.lookup(url: raw)
                } else {
                    metadata = try await store.appStoreLookup.lookup(bundleId: raw)
                }
                let artworkData: Data?
                if let artworkURL = metadata.artworkURL {
                    artworkData = try? await store.appStoreLookup.downloadArtwork(artworkURL)
                } else {
                    artworkData = nil
                }
                await MainActor.run {
                    self.applyLookup(metadata: metadata, artwork: artworkData)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Couldn't find that on the App Store. Fill the fields manually if you prefer."
                }
            }
        }
    }

    @MainActor
    private func applyLookup(metadata: AppStoreLookup.AppMetadata, artwork: Data?) {
        if displayName.isEmpty { displayName = metadata.name }
        if bundleId.isEmpty { bundleId = metadata.bundleId }
        if iconData == nil { iconData = artwork }
        errorMessage = nil
    }

    @MainActor
    private func loadKey(from url: URL) async {
        do {
            let pem = try PEMParser.readPEM(fromFile: url)
            pemContents = pem
            pemFileName = url.lastPathComponent
            let stem = url.deletingPathExtension().lastPathComponent
            if stem.hasPrefix("AuthKey_"), keyId.isEmpty {
                keyId = String(stem.dropFirst("AuthKey_".count))
            }
        } catch let error as PeelError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var canSubmit: Bool {
        AppConfigValidator.validateBundleId(bundleId).isValid &&
        AppConfigValidator.validateIssuerId(issuerId).isValid &&
        AppConfigValidator.validateKeyId(keyId).isValid &&
        !displayName.isEmpty &&
        !pemContents.isEmpty
    }

    private func commit() async {
        let config = AppConfig(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            bundleId: bundleId.trimmingCharacters(in: .whitespacesAndNewlines),
            issuerId: issuerId.trimmingCharacters(in: .whitespacesAndNewlines),
            keyId: keyId.trimmingCharacters(in: .whitespacesAndNewlines),
            environmentSupport: .both,
            accentColorHex: derivedAccentHex,
            iconData: iconData
        )
        do {
            _ = try PEMParser.privateKey(fromPEM: pemContents)
            try await store.addApp(config, pem: pemContents)
            isPresented = false
        } catch let error as PeelError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension Color {
    func toHexString() -> String? {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB)
        guard let c = nsColor else { return nil }
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
