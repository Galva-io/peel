import SwiftUI
import PeelCore
import PeelAPI

/// The request editor — top half of the editor/debug split. Rendered as an
/// Xcode-style inspector form: right-aligned secondary labels in a fixed
/// gutter, control on the right, help and inline errors stacked beneath.
/// Two sections only — Parameters and Action — separated by a 0.5-pt
/// underline below each section header.
public struct RequestPanel: View {
    @Bindable public var store: PeelAppStore
    public let selection: SidebarSelection
    @State private var showingJWT = false
    @State private var sending = false
    @State private var pendingConfirmation: EndpointConfirmation?

    public init(store: PeelAppStore, selection: SidebarSelection) {
        self.store = store
        self.selection = selection
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InspectorFormMetrics.sectionSpacing) {
                parametersSection
                actionsSection
                if showingJWT { jwtPreview }
                if let error = store.lastErrors[selection] {
                    ErrorBanner(error: error)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(maxHeight: .infinity)
        .background(.background)
        .onReceive(NotificationCenter.default.publisher(for: .peelSendRequest)) { _ in
            Task { await send() }
        }
        .sheet(item: $pendingConfirmation) { confirmation in
            ConfirmationSheet(
                confirmation: confirmation,
                onConfirm: {
                    pendingConfirmation = nil
                    Task { await performSend() }
                },
                onCancel: {
                    pendingConfirmation = nil
                }
            )
        }
    }

    private var endpoint: EndpointID { selection.endpoint }

    private var parameters: Binding<RequestParameters> {
        Binding(
            get: { store.requestParameters[selection] ?? RequestParameters() },
            set: { store.requestParameters[selection] = $0 }
        )
    }

    // MARK: - Parameters section

    private var parametersSection: some View {
        let fields = EndpointCatalog.fields(for: endpoint)
        let suggestions = store.recentTransactionIds
        return InspectorFormSection(title: "Parameters") {
            if fields.isEmpty {
                InspectorFormRow(label: "") {
                    Text("No parameters required.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(fields) { field in
                    InspectorFormRow(
                        label: field.label,
                        isRequired: field.isRequired,
                        help: field.help,
                        error: errorMessage(for: field)
                    ) {
                        ParameterControl(
                            field: field,
                            value: binding(for: field.id),
                            transactionSuggestions: suggestions
                        )
                    }
                }
            }
        }
        .onAppear { applyEndpointDefaults() }
        .onChange(of: selection) { _, _ in applyEndpointDefaults() }
    }

    private func errorMessage(for field: ParameterField) -> String? {
        let value = parameters.wrappedValue[field.id] ?? ""
        guard !value.isEmpty, let message = field.validate(value).message else { return nil }
        return message
    }

    // MARK: - Actions section

    private var actionsSection: some View {
        InspectorFormSection(title: "Action") {
            InspectorFormActions {
                Button {
                    Task { await send() }
                } label: {
                    HStack(spacing: 6) {
                        if sending { ProgressView().controlSize(.small) }
                        Text(sending ? "Sending…" : "Send")
                    }
                    .frame(minWidth: 72)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(sending || !canSend)
                .tint(store.environment == .production ? PeelTheme.productionTint : .accentColor)

                Menu {
                    Button("Copy as curl", action: copyCurl)
                        .disabled(!canSend)
                    Toggle("Show signed JWT", isOn: $showingJWT)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
                .help("More actions")
            }
        }
    }

    private var jwtPreview: some View {
        InspectorFormSection(title: "Signed JWT") {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(store.lastResults[selection]?.response.jwt ?? "(not yet signed — send to generate)")
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    // MARK: - Behavior

    /// Inject endpoint-specific defaults so the form looks usable from first
    /// open. We only fill empty fields.
    private func applyEndpointDefaults() {
        var current = parameters.wrappedValue
        var changed = false
        switch endpoint {
        case .getNotificationHistory:
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let dayMs: Int64 = 24 * 60 * 60 * 1000
            if (current["endDate"] ?? "").isEmpty {
                current["endDate"] = "\(now)"
                changed = true
            }
            if (current["startDate"] ?? "").isEmpty {
                current["startDate"] = "\(now - dayMs)"
                changed = true
            }
            if (current["itemLimit"] ?? "").isEmpty {
                current["itemLimit"] = "20"
                changed = true
            }
        default:
            break
        }
        if changed { parameters.wrappedValue = current }
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

    private var canSend: Bool {
        guard store.activeApp != nil else { return false }
        let fields = EndpointCatalog.fields(for: endpoint)
        for f in fields {
            if !f.validate(parameters.wrappedValue[f.id]).isValid { return false }
        }
        if store.isReadOnly && endpoint.isMutating { return false }
        return true
    }

    /// Entry point invoked from the Send button and the `peelSendRequest`
    /// notification. For mutating endpoints we present a confirmation
    /// sheet first; `performSend` is the actual dispatch path that runs
    /// either immediately (read endpoints) or after the user confirms.
    private func send() async {
        guard canSend else { return }
        if let app = store.activeApp,
           let confirmation = EndpointConfirmationBuilder.describe(
               endpoint: endpoint,
               parameters: parameters.wrappedValue,
               environment: store.environment,
               appName: app.displayName
           ) {
            pendingConfirmation = confirmation
            return
        }
        await performSend()
    }

    private func performSend() async {
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

/// The control that goes in the right column of `InspectorFormRow` for a
/// given `ParameterField`. Bool fields use `.checkbox` (Xcode build-setting
/// style), date fields use a compact `DatePicker`, enums use `.menu`, and
/// transaction IDs upgrade to `AutocompleteField` when suggestions exist.
struct ParameterControl: View {
    let field: ParameterField
    @Binding var value: String
    var transactionSuggestions: [String] = []

    var body: some View {
        Group {
            switch field.kind {
            case .longText:
                TextEditor(text: $value)
                    .frame(minHeight: 70)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            case let .enumeration(options):
                Picker("", selection: $value) {
                    Text("Any").tag("")
                    ForEach(options, id: \.self) { opt in
                        Text(opt).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
            case let .codedEnum(options):
                Picker("", selection: $value) {
                    if !options.contains(where: { $0.value == value }) {
                        Text("—").tag("")
                    }
                    ForEach(options) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
            case .countryCodeTags:
                CountryTagField(codesString: $value)
            case .bool:
                Toggle("", isOn: Binding(
                    get: { value.lowercased() == "true" },
                    set: { value = $0 ? "true" : "false" }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
            case .dateMillis:
                DatePicker(
                    "",
                    selection: dateBinding(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .controlSize(.small)
            case .transactionId where !transactionSuggestions.isEmpty:
                AutocompleteField(
                    text: $value,
                    placeholder: field.placeholder,
                    suggestions: transactionSuggestions
                )
                .frame(height: 20)
            default:
                TextField("", text: $value, prompt: field.placeholder.map(Text.init))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }
        }
    }

    private func dateBinding() -> Binding<Date> {
        Binding(
            get: {
                guard let ms = Int64(value), ms > 0 else { return Date() }
                return Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
            },
            set: { newDate in
                value = "\(Int64(newDate.timeIntervalSince1970 * 1000))"
            }
        )
    }
}

struct ErrorBanner: View {
    let error: PeelError

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .imageScale(.small)
                Text(error.title).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(PeelTheme.productionTint)

            Text(error.message).font(.system(size: 11))
            if let remediation = error.remediation {
                Text(remediation).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PeelTheme.productionTint.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(PeelTheme.productionTint.opacity(0.3))
        )
    }
}
