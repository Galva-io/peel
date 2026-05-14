import SwiftUI
import PeelCore
import PeelAPI

/// Lower pane of the editor split — the debug area equivalent. Top of the
/// pane is a slim control strip with the tab segmented control on the
/// left, status pill + timing on the right, and a Copy button trailing.
/// Below sits whichever of Decoded / Raw JSON / HTTP is active.
public struct ResponseViewer: View {
    @Bindable public var store: PeelAppStore
    public let selection: SidebarSelection
    @State private var selectedTab: Tab = .decoded
    @State private var copyFeedback: Bool = false

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
        VStack(spacing: 0) {
            controlStrip
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .onReceive(NotificationCenter.default.publisher(for: .peelMarkCompare)) { _ in
            // Existing compare-pane integration retained.
        }
    }

    private var lastResult: PeelAppStore.DispatchResult? { store.lastResults[selection] }

    private var controlStrip: some View {
        HStack(spacing: 10) {
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.displayName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .frame(maxWidth: 220)

            Spacer()

            if let response = lastResult?.response {
                statusPill(response.status)
                Text("\(response.durationMs) ms")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: Int64(response.body.count), countStyle: .file))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)

                copyButton
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(.bar)
    }

    /// Copies whatever the active tab is showing. Decoded / Raw JSON copy
    /// the pretty-printed JSON; HTTP copies a request + response summary.
    private var copyButton: some View {
        Button {
            copyActiveContent()
            withAnimation(.easeInOut(duration: 0.12)) { copyFeedback = true }
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                await MainActor.run { copyFeedback = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copyFeedback ? "checkmark" : "doc.on.doc")
                    .imageScale(.small)
                Text(copyFeedback ? "Copied" : "Copy")
                    .font(.system(size: 11))
            }
        }
        .buttonStyle(.borderless)
        .help("Copy the current view (⌘C copies inside Decoded too)")
    }

    private func copyActiveContent() {
        guard let result = lastResult else { return }
        let text: String
        switch selectedTab {
        case .decoded:
            text = result.decoded.encodePretty()
        case .json:
            if let parsed = try? JSONValue(data: result.response.body) {
                text = parsed.encodePretty()
            } else {
                text = String(data: result.response.body, encoding: .utf8) ?? ""
            }
        case .http:
            text = httpSummary(of: result.response)
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Plain-text "Request → Response" report. Same shape as Xcode's
    /// "Copy as Markdown" but unadorned so it pastes cleanly into a Linear
    /// ticket or Slack thread.
    private func httpSummary(of response: PeelAPI.Client.APIResponse) -> String {
        var lines: [String] = []
        lines.append("\(response.request.httpMethod ?? "GET") \(response.request.url?.absoluteString ?? "")")
        for (k, v) in (response.request.allHTTPHeaderFields ?? [:]).sorted(by: { $0.key < $1.key }) {
            lines.append("\(k): \(v)")
        }
        lines.append("")
        lines.append("→ \(response.status)  \(response.durationMs) ms")
        for (k, v) in response.headers.sorted(by: { $0.key < $1.key }) {
            lines.append("\(k): \(v)")
        }
        return lines.joined(separator: "\n")
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
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
                Text("No response yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Press Send (⌘↩).")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func statusPill(_ status: Int) -> some View {
        let label: String = {
            switch status {
            case 200..<300: return "\(status) OK"
            case 400..<500: return "\(status) Client error"
            case 500...: return "\(status) Server error"
            default: return "\(status)"
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(statusColor(status).opacity(0.16), in: Capsule())
            .foregroundStyle(statusColor(status))
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
                .font(.system(size: 12, design: .monospaced))
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
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            body()
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .trailing)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
        }
    }
}
