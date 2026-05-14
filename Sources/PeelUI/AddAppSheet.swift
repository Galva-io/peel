import SwiftUI
import UniformTypeIdentifiers
import PeelCore

public struct AddAppSheet: View {
    @Bindable public var store: PeelAppStore
    @Binding public var isPresented: Bool

    @State private var displayName = ""
    @State private var bundleId = ""
    @State private var issuerId = ""
    @State private var keyId = ""
    @State private var pemContents: String = ""
    @State private var environmentSupport: AppEnvironmentSupport = .both
    @State private var accentHex = "#0A84FF"
    @State private var errorMessage: String?
    @State private var isDropTargeted = false

    public init(store: PeelAppStore, isPresented: Binding<Bool>) {
        self.store = store
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add an app context")
                .font(.title3.weight(.semibold))
            Text("Drag your .p8 key onto the well, or paste its contents. Peel parses the Key ID from the filename when you drop a file.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Form {
                TextField("Display name", text: $displayName)
                    .accessibilityLabel("App display name")
                TextField("Bundle ID", text: $bundleId, prompt: Text("com.example.app"))
                TextField("Issuer ID", text: $issuerId, prompt: Text("UUID from App Store Connect"))
                TextField("Key ID", text: $keyId, prompt: Text("10-character key ID"))
                Picker("Environment", selection: $environmentSupport) {
                    Text("Sandbox + Production").tag(AppEnvironmentSupport.both)
                    Text("Sandbox only").tag(AppEnvironmentSupport.sandboxOnly)
                    Text("Production only").tag(AppEnvironmentSupport.productionOnly)
                }
                ColorPicker("Accent", selection: Binding(get: {
                    Color(hex: accentHex) ?? .accentColor
                }, set: { color in
                    accentHex = color.toHexString() ?? accentHex
                }))
            }

            keyDropWell

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(PeelTheme.productionTint)
                    .padding(.top, 4)
            }

            Spacer()

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add app") { Task { await commit() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
            }
        }
        .padding(24)
        .frame(width: 480, height: 580)
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
                        Text("Key loaded · \(pemContents.count) bytes")
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
                    }
                }
            }
    }

    @MainActor
    private func loadKey(from url: URL) async {
        do {
            let pem = try PEMParser.readPEM(fromFile: url)
            pemContents = pem
            // Apple names the file `AuthKey_XXXXXXXXXX.p8` — the trailing 10 chars are the key ID.
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
            accentColorHex: accentHex
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
