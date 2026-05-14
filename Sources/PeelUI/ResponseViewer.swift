import SwiftUI
import PeelCore
import PeelAPI

public struct ResponseViewer: View {
    @Bindable public var store: PeelAppStore
    @Binding public var lastResult: PeelAppStore.DispatchResult?
    @State private var selectedTab: Tab = .decoded
    @State private var searchTerm: String = ""

    public init(store: PeelAppStore, lastResult: Binding<PeelAppStore.DispatchResult?>) {
        self.store = store
        self._lastResult = lastResult
    }

    public enum Tab: String, Hashable, CaseIterable, Identifiable {
        case decoded, json, http
        public var id: String { rawValue }
        public var displayName: String {
            switch self {
            case .decoded: return "Decoded"
            case .json: return "Raw JSON"
            case .http: return "HTTP"
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 360)
        .toolbar {
            if lastResult != nil {
                ToolbarItem {
                    Button {
                        if let r = lastResult {
                            NotificationCenter.default.post(name: .peelMarkCompare, object: r.response.body)
                        }
                    } label: {
                        Label("Mark for compare", systemImage: "rectangle.on.rectangle")
                    }
                    .help("Mark this response so the next response can be diffed against it (⌘⇧M)")
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.displayName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 260)

            Spacer()

            if let response = lastResult?.response {
                Text(statusLabel(response.status))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(statusColor(response.status).opacity(0.15),
                                in: Capsule())
                    .foregroundStyle(statusColor(response.status))
                Text("\(response.durationMs) ms")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if let lastResult {
            switch selectedTab {
            case .decoded:
                DecodedTreeView(root: lastResult.decoded, searchTerm: $searchTerm)
            case .json:
                JSONTextView(value: lastResult.decoded, raw: lastResult.response.body)
            case .http:
                HTTPInfoView(response: lastResult.response)
            }
        } else {
            ContentUnavailableView(
                "No response yet",
                systemImage: "tray",
                description: Text("Pick an endpoint, fill in parameters, and press Send (⌘↩).")
            )
        }
    }

    private func statusLabel(_ status: Int) -> String {
        switch status {
        case 200..<300: return "\(status) OK"
        case 400..<500: return "\(status) Client error"
        case 500...: return "\(status) Server error"
        default: return "\(status)"
        }
    }

    private func statusColor(_ status: Int) -> Color {
        switch status {
        case 200..<300: return .green
        case 400..<500: return .orange
        case 500...: return PeelTheme.productionTint
        default: return .secondary
        }
    }
}

struct DecodedTreeView: View {
    let root: JSONValue
    @Binding var searchTerm: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find in response", text: $searchTerm)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    JSONNodeView(name: "$", value: root, depth: 0, searchTerm: searchTerm)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct JSONNodeView: View {
    let name: String
    let value: JSONValue
    let depth: Int
    let searchTerm: String
    @State private var expanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch value {
            case let .object(pairs):
                disclosureRow(label: "{ \(pairs.count) field\(pairs.count == 1 ? "" : "s") }")
                if expanded {
                    ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                        JSONNodeView(name: pair.key, value: pair.value, depth: depth + 1, searchTerm: searchTerm)
                    }
                }
            case let .array(items):
                disclosureRow(label: "[ \(items.count) item\(items.count == 1 ? "" : "s") ]")
                if expanded {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, child in
                        JSONNodeView(name: "[\(index)]", value: child, depth: depth + 1, searchTerm: searchTerm)
                    }
                }
            default:
                leafRow
            }
        }
        .padding(.leading, CGFloat(depth) * 14)
    }

    private func disclosureRow(label: String) -> some View {
        HStack(spacing: 4) {
            Button {
                expanded.toggle()
            } label: {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .imageScale(.small)
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Text(name).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            Text(label).font(.system(.caption, design: .monospaced)).foregroundStyle(.tertiary)
            if isJWSEnvelope { jwsBadge }
            Spacer()
        }
        .background(highlight)
    }

    private var leafRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .imageScale(.small)
                .foregroundStyle(.tertiary)
                .opacity(0.3)
            Text(name).font(.system(.caption, design: .monospaced))
            Text(":").foregroundStyle(.secondary)
            Text(leafText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(leafColor)
                .textSelection(.enabled)
            if let semantic = SemanticFieldDescriptions.label(for: name) {
                Text("· \(semantic)").font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .background(highlight)
        .contextMenu {
            Button("Copy value") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(leafText, forType: .string)
            }
            Button("Copy \"key\": value") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\"\(name)\": \(leafText)", forType: .string)
            }
        }
    }

    private var leafText: String {
        switch value {
        case .null: return "null"
        case let .bool(b): return b ? "true" : "false"
        case let .number(n): return n.literal
        case let .string(s): return "\"" + s + "\""
        default: return value.encodeCompact()
        }
    }

    private var leafColor: Color {
        switch value {
        case .null: return .secondary
        case .bool: return .orange
        case .number: return .blue
        case .string: return .green
        default: return .primary
        }
    }

    private var isJWSEnvelope: Bool {
        guard case let .object(pairs) = value else { return false }
        return pairs.contains { $0.key == "__peel_jws" }
    }

    private var jwsBadge: some View {
        Text("decoded JWS")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(.tint)
    }

    @ViewBuilder
    private var highlight: some View {
        if !searchTerm.isEmpty && (name.localizedCaseInsensitiveContains(searchTerm) ||
                                   leafText.localizedCaseInsensitiveContains(searchTerm)) {
            Color.yellow.opacity(0.18)
        } else {
            Color.clear
        }
    }
}

struct JSONTextView: View {
    let value: JSONValue
    let raw: Data

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(pretty)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var pretty: String {
        let parsed = try? JSONValue(data: raw)
        return parsed?.encodePretty() ?? value.encodePretty()
    }
}

struct HTTPInfoView: View {
    let response: PeelAPI.Client.APIResponse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section("Request") {
                    keyValue("Method", response.request.httpMethod ?? "?")
                    keyValue("URL", response.request.url?.absoluteString ?? "?")
                    ForEach(Array(response.request.allHTTPHeaderFields ?? [:]).sorted(by: { $0.key < $1.key }), id: \.key) { pair in
                        keyValue(pair.key, pair.value)
                    }
                }
                section("Response") {
                    keyValue("Status", "\(response.status)")
                    keyValue("Duration", "\(response.durationMs) ms")
                    ForEach(Array(response.headers).sorted(by: { $0.key < $1.key }), id: \.key) { pair in
                        keyValue(pair.key, pair.value)
                    }
                }
                if let diagnosis = response.diagnosis {
                    section("Diagnosis") {
                        Text(diagnosis.title).font(.callout.weight(.semibold))
                        Text(diagnosis.body)
                        Text(diagnosis.remediation).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ body: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            body()
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
        }
    }
}

/// Plain-English labels for well-known App Store Server API fields. Hovering
/// a field surfaces this. Add to the dictionary as Apple ships new fields.
public enum SemanticFieldDescriptions {
    public static let labels: [String: String] = [
        "appAccountToken": "Developer-supplied user ID for the purchase",
        "autoRenewStatus": "1 = on, 0 = off",
        "bundleId": "App's bundle identifier",
        "currency": "ISO-4217 currency code",
        "environment": "Apple-supplied environment label",
        "expiresDate": "Epoch ms when this period ends",
        "inAppOwnershipType": "Family Sharing ownership type",
        "originalTransactionId": "Stable ID for the entire subscription chain",
        "price": "Price in micro-units",
        "productId": "App Store product identifier",
        "purchaseDate": "Epoch ms when the purchase was made",
        "quantity": "Number of items purchased",
        "revocationDate": "Epoch ms when the purchase was revoked",
        "revocationReason": "0 = other, 1 = refund",
        "signedDate": "Epoch ms when Apple signed the payload",
        "status": "1 active, 2 expired, 3 in billing retry, 4 in grace period, 5 revoked",
        "subscriptionGroupIdentifier": "Subscription group ID",
        "transactionId": "Unique ID for this transaction",
        "type": "Product type (Auto-Renewable, Non-Consumable, etc.)",
        "webOrderLineItemId": "Cross-storefront stable ID for a renewal"
    ]

    public static func label(for key: String) -> String? { labels[key] }
}
