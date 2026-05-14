import SwiftUI
import UniformTypeIdentifiers
import PeelCore

/// The Add App sheet is the only place a user pastes a `.p8` private key in
/// Peel. To make it feel less like a database form we lead with the App
/// Store URL (or bundle id) — paste it, hit Tab, and Peel fills in the
/// display name, bundle id, and icon by talking to Apple's public iTunes
/// Lookup API. The user then provides Issuer ID + Key ID + the .p8 file.
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
    @State private var environmentSupport: AppEnvironmentSupport = .both
    @State private var accentHex = "#0A84FF"
    @State private var iconData: Data?
    @State private var errorMessage: String?
    @State private var isDropTargeted = false
    @State private var isLookingUp = false
    @State private var lookupTask: Task<Void, Never>?

    public init(store: PeelAppStore, isPresented: Binding<Bool>) {
        self.store = store
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            appStoreLookupField
            iconAndForm
            keyDropWell
            errorBlock
            Spacer(minLength: 0)
            footer
        }
        .padding(24)
        .frame(width: 540, height: 660)
        .onDisappear { lookupTask?.cancel() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Add an app context")
                .font(.title3.weight(.semibold))
            Text("Paste an App Store link or bundle id and Peel will fetch the name and icon. Drop your .p8 file to auto-fill the Key ID.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appStoreLookupField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                TextField(
                    "App Store URL, app ID, or bundle id",
                    text: $appStoreInput,
                    prompt: Text("https://apps.apple.com/…/id1234567890")
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit { triggerLookup() }
                Button("Fetch") { triggerLookup() }
                    .disabled(appStoreInput.trimmingCharacters(in: .whitespaces).isEmpty || isLookingUp)
                if isLookingUp {
                    ProgressView().controlSize(.small)
                }
            }
            Text("Optional. We call Apple's public iTunes Lookup API — same one App Store badges use.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var iconAndForm: some View {
        HStack(alignment: .top, spacing: 16) {
            previewIcon
            Form {
                TextField("Display name", text: $displayName)
                TextField("Bundle ID", text: $bundleId, prompt: Text("com.example.app"))
                TextField("Issuer ID", text: $issuerId, prompt: Text("UUID from App Store Connect"))
                TextField("Key ID", text: $keyId, prompt: Text("10-character key ID"))
                Picker("Environment", selection: $environmentSupport) {
                    Text("Sandbox + Production").tag(AppEnvironmentSupport.both)
                    Text("Sandbox only").tag(AppEnvironmentSupport.sandboxOnly)
                    Text("Production only").tag(AppEnvironmentSupport.productionOnly)
                }
                ColorPicker(
                    "Accent",
                    selection: Binding(
                        get: { Color(hex: accentHex) ?? .accentColor },
                        set: { color in accentHex = color.toHexString() ?? accentHex }
                    )
                )
            }
        }
    }

    private var previewIcon: some View {
        let preview = AppConfig(
            displayName: displayName.isEmpty ? "New App" : displayName,
            bundleId: bundleId,
            issuerId: issuerId,
            keyId: keyId,
            accentColorHex: accentHex,
            iconData: iconData
        )
        return AppIconView(app: preview, size: 64)
    }

    private var keyDropWell: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
            .foregroundStyle(isDropTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
            .frame(height: 90)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: pemContents.isEmpty ? "doc.badge.arrow.up" : "key.fill")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                    if pemContents.isEmpty {
                        Text("Drop .p8 key here").font(.callout)
                    } else {
                        Text(pemFileName.map { "Loaded \($0)" } ?? "Key loaded · \(pemContents.count) bytes")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
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
            .contextMenu {
                Button("Paste from clipboard") {
                    if let pasted = NSPasteboard.general.string(forType: .string) {
                        pemContents = pasted
                        pemFileName = nil
                    }
                }
            }
    }

    @ViewBuilder
    private var errorBlock: some View {
        if let errorMessage {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(PeelTheme.productionTint)
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer()
                Button("Dismiss") { self.errorMessage = nil }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") { isPresented = false }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Add app") { Task { await commit() } }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
        }
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
                    // Looks like a bundle id — try that first.
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
            // Apple names the file `AuthKey_XXXXXXXXXX.p8` — the trailing 10
            // chars are the Key ID. We only auto-fill if the user hasn't
            // typed something there already.
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
            environmentSupport: environmentSupport,
            accentColorHex: accentHex,
            iconData: iconData
        )
        do {
            // Validate the PEM by trying to parse it before persisting.
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
