import SwiftUI
import PeelCore
import PeelAPI

public struct ResponseViewer: View {
    @Bindable public var store: PeelAppStore
    public let selection: SidebarSelection
    @State private var selectedTab: Tab = .decoded

    public init(store: PeelAppStore, selection: SidebarSelection) {
        self.store = store
        self.selection = selection
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
        .frame(minWidth: 380)
        .toolbar {
            if store.lastResults[selection] != nil {
                ToolbarItem {
                    Button {
                        if let r = store.lastResults[selection] {
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

    private var lastResult: PeelAppStore.DispatchResult? { store.lastResults[selection] }

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
                    .background(statusColor(response.status).opacity(0.15), in: Capsule())
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
                DecodedWebView(value: lastResult.decoded)
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

