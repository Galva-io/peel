import SwiftUI
import PeelCore
import PeelAPI

public struct RequestPanel: View {
    @Bindable public var store: PeelAppStore
    public let selection: SidebarSelection
    @State private var showingJWT = false
    @State private var sending = false

    public init(store: PeelAppStore, selection: SidebarSelection) {
        self.store = store
        self.selection = selection
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                endpointHeader
                Divider()
                parameterForm
                Divider()
                actions
                if showingJWT { jwtPreview }
                if let error = store.lastErrors[selection] {
                    ErrorBanner(error: error)
                }
            }
            .padding(16)
        }
        .onReceive(NotificationCenter.default.publisher(for: .peelSendRequest)) { _ in
            Task { await send() }
        }
    }

    private var endpoint: EndpointID { selection.endpoint }

    private var parameters: Binding<RequestParameters> {
        Binding(
            get: { store.requestParameters[selection] ?? RequestParameters() },
            set: { store.requestParameters[selection] = $0 }
        )
    }

    private var endpointHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(endpoint.displayName).font(.title3.weight(.semibold))
                if endpoint.isMutating {
                    Label("Mutating", systemImage: "exclamationmark.shield.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(PeelTheme.productionTint)
                }
                Spacer()
                Link(destination: endpoint.docsURL) {
                    Label("Docs", systemImage: "book.closed")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                }
            }
            Text(endpoint.category.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var parameterForm: some View {
        let fields = EndpointCatalog.fields(for: endpoint)
        return Group {
            if fields.isEmpty {
                Text("No parameters required.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(fields) { field in
                        ParameterRow(field: field, value: binding(for: field.id))
                    }
                }
            }
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { parameters.wrappedValue[key] ?? "" },
            set: { v in
                var current = parameters.wrappedValue
                current[key] = v
                parameters.wrappedValue = current
            }
        )
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                Task { await send() }
            } label: {
                HStack(spacing: 6) {
                    if sending { ProgressView().controlSize(.small) }
                    Text(sending ? "Sending…" : "Send")
                }
                .frame(minWidth: 70)
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(sending || !canSend)
            .tint(store.environment == .production ? PeelTheme.productionTint : .accentColor)

            Button("Copy as curl") { copyCurl() }
                .disabled(!canSend)

            Toggle(isOn: $showingJWT) {
                Label("Show JWT", systemImage: "key")
            }
            .toggleStyle(.button)
            .controlSize(.regular)

            Spacer()

            if store.environment == .production {
                Label("Production", systemImage: "exclamationmark.octagon.fill")
                    .foregroundStyle(PeelTheme.productionTint)
                    .font(.caption.weight(.semibold))
            }
            if store.isReadOnly && endpoint.isMutating {
                Label("Disabled by read-only mode", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var jwtPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("JWT").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                Text(store.lastResults[selection]?.response.jwt ?? "(not yet signed — send to generate)")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var canSend: Bool {
        guard store.activeApp != nil else { return false }
        let fields = EndpointCatalog.fields(for: endpoint)
        for f in fields {
            if !f.validate(parameters.wrappedValue[f.id]).isValid { return false }
        }
        if store.isReadOnly && endpoint.isMutating { return false }
        return true
    }

    private func send() async {
        guard canSend else { return }
        sending = true
        defer { sending = false }
        do {
            let result = try await store.send(endpoint: endpoint, parameters: parameters.wrappedValue)
            store.lastResults[selection] = result
            store.lastErrors[selection] = nil
        } catch let error as PeelError {
            store.lastErrors[selection] = error
        } catch {
            store.lastErrors[selection] = PeelError(kind: .unknown, title: "Unexpected", message: error.localizedDescription)
        }
    }

    private func copyCurl() {
        do {
            let spec = try EndpointBuilder.build(endpoint: endpoint, parameters: parameters.wrappedValue)
            guard let app = store.activeApp else { return }
            let url = spec.url(in: store.environment)
            var request = URLRequest(url: url)
            request.httpMethod = spec.method.rawValue
            request.setValue("Bearer <JWT for \(app.displayName)>", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let body = spec.body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = body
            }
            let curl = CurlFormatter.render(request)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(curl, forType: .string)
        } catch { }
    }
}

struct ParameterRow: View {
    let field: ParameterField
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(field.label).font(.callout.weight(.medium))
                if field.isRequired { Text("*").foregroundStyle(PeelTheme.productionTint) }
            }
            input
            if let help = field.help {
                Text(help).font(.caption).foregroundStyle(.secondary)
            }
            if let message = field.validate(value).message, !value.isEmpty {
                Text(message).font(.caption).foregroundStyle(PeelTheme.productionTint)
            }
        }
    }

    @ViewBuilder
    private var input: some View {
        switch field.kind {
        case .longText:
            TextEditor(text: $value)
                .frame(minHeight: 80)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        case let .enumeration(options):
            Picker("", selection: $value) {
                Text("—").tag("")
                ForEach(options, id: \.self) { opt in
                    Text(opt).tag(opt)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        case .bool:
            Toggle("", isOn: Binding(get: { value.lowercased() == "true" }, set: { value = $0 ? "true" : "false" }))
        default:
            TextField("", text: $value, prompt: field.placeholder.map(Text.init))
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct ErrorBanner: View {
    let error: PeelError

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(error.title).font(.callout.weight(.semibold))
            }
            .foregroundStyle(PeelTheme.productionTint)

            Text(error.message).font(.callout)
            if let remediation = error.remediation {
                Text(remediation).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PeelTheme.productionTint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(PeelTheme.productionTint.opacity(0.3))
        )
    }
}
