import SwiftUI
import PeelCore
import PeelAPI
import PeelPersistence

/// Xcode's right pane — the Inspector. Sections with disclosure
/// triangles, key/value rows, all expanded by default. The width is fixed
/// at 280 (Xcode's File Inspector is ~270) and the content is read-only:
/// the inspector reports state, it never owns it.
struct InspectorView: View {
    @Bindable var store: PeelAppStore
    let selection: SidebarSelection

    private var endpoint: EndpointID { selection.endpoint }
    private var lastResult: PeelAppStore.DispatchResult? { store.lastResults[selection] }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                endpointSection
                Divider()
                lastResponseSection
                Divider()
                authSection
                Divider()
                recentSection
            }
        }
        .frame(minWidth: 260, idealWidth: 280, maxWidth: 360)
        .background(.background)
    }

    // MARK: - Sections

    private var endpointSection: some View {
        InspectorSection(title: "Endpoint") {
            kv("Method", endpoint.httpMethod.label, mono: true)
            kv("Category", endpoint.category.displayName)
            kv("Mutating", endpoint.isMutating ? "Yes" : "No", warning: endpoint.isMutating)
            HStack {
                Text("Documentation")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Link("Apple Developer", destination: endpoint.docsURL)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 20)
        }
    }

    @ViewBuilder
    private var lastResponseSection: some View {
        InspectorSection(title: "Last Response") {
            if let r = lastResult?.response {
                kv("Status", "\(r.status)", warning: r.status >= 400, mono: true)
                kv("Time", "\(r.durationMs) ms", mono: true)
                kv("Size", ByteCountFormatter.string(fromByteCount: Int64(r.body.count), countStyle: .file), mono: true)
                if let diag = r.diagnosis {
                    InspectorDiagnosis(title: diag.title, message: diag.remediation)
                }
            } else {
                placeholder("Send a request to populate")
            }
        }
    }

    @ViewBuilder
    private var authSection: some View {
        InspectorSection(title: "Authentication") {
            if let app = store.activeApp {
                kv("App", app.displayName)
                kv("Bundle ID", app.bundleId, mono: true, truncatable: true)
                kv("Issuer", app.issuerId, mono: true, truncatable: true)
                kv("Key ID", app.keyId, mono: true)
                if lastResult?.response != nil {
                    kv("JWT", "Signed", success: true)
                }
            } else {
                placeholder("No app selected")
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        let recents = store.history
            .filter { $0.endpoint == endpoint }
            .prefix(5)
        InspectorSection(title: "Recent Calls") {
            if recents.isEmpty {
                placeholder("No calls yet")
            } else {
                ForEach(Array(recents), id: \.id) { record in
                    InspectorRecentRow(record: record)
                }
            }
        }
    }

    // MARK: - Helpers

    private func kv(
        _ key: String,
        _ value: String,
        warning: Bool = false,
        success: Bool = false,
        mono: Bool = false,
        truncatable: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(mono ? .system(size: 11, design: .monospaced) : .system(size: 11))
                .foregroundStyle(warning ? PeelTheme.productionTint : (success ? Color.green : Color.primary))
                .lineLimit(1)
                .truncationMode(truncatable ? .middle : .tail)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 20)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Disclosure section header + body. Open by default, collapsible. Spacing
/// matches Xcode's inspector: 6-pt header, 4-pt content gap.
struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @State private var expanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.12)) { expanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .imageScale(.small)
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(height: 22)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct InspectorDiagnosis: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PeelTheme.productionTint)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

struct InspectorRecentRow: View {
    let record: PeelPersistence.Storage.HistoryRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
            Text("\(record.responseStatus)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(statusColor)
            Text(record.sentAt, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(record.durationMs) ms")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 20)
    }

    private var statusColor: Color {
        switch record.responseStatus {
        case 200..<300: return .green
        case 400..<500: return .orange
        case 500...: return PeelTheme.productionTint
        default: return .secondary
        }
    }
}
