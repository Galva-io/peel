import SwiftUI
import PeelCore

public struct ComparePanel: View {
    @Bindable public var store: PeelAppStore
    @State private var leftRaw: Data?
    @State private var rightRaw: Data?

    public init(store: PeelAppStore) { self.store = store }

    public var body: some View {
        HSplitView {
            pane(side: "Before", raw: $leftRaw)
            pane(side: "After", raw: $rightRaw)
            diffPane
        }
        .navigationTitle("Compare Responses")
        .onReceive(NotificationCenter.default.publisher(for: .peelMarkCompare)) { note in
            guard let data = note.object as? Data else { return }
            if leftRaw == nil {
                leftRaw = data
            } else if rightRaw == nil {
                rightRaw = data
            } else {
                rightRaw = data
            }
        }
    }

    private func pane(side: String, raw: Binding<Data?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(side).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Menu("Load…") {
                    ForEach(store.history.prefix(20)) { record in
                        Button("\(record.endpoint.displayName) · \(record.responseStatus)") {
                            Task {
                                if let body = try? await store.storage.loadResponseBody(for: record) {
                                    raw.wrappedValue = body
                                }
                            }
                        }
                    }
                }
                Button("Clear") { raw.wrappedValue = nil }
                    .disabled(raw.wrappedValue == nil)
            }
            .padding(.horizontal, 10).padding(.top, 8)
            Divider()
            ScrollView {
                Text(pretty(raw.wrappedValue))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 240)
    }

    private var diffPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diff").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.top, 8)
            Divider()
            if let summary {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if !summary.headline.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Summary").font(.caption).foregroundStyle(.secondary)
                                ForEach(summary.headline, id: \.self) { line in
                                    Label(line, systemImage: "arrow.right")
                                        .font(.callout)
                                }
                            }
                        }
                        ForEach(Array(summary.changes.enumerated()), id: \.offset) { _, change in
                            DiffRow(change: change)
                        }
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(summary.markdown, forType: .string)
                        } label: {
                            Label("Copy as Markdown", systemImage: "doc.on.clipboard")
                        }
                    }
                    .padding(10)
                }
            } else {
                ContentUnavailableView(
                    "Pick two responses",
                    systemImage: "rectangle.on.rectangle.angled",
                    description: Text("Load Before and After from history, or mark fresh responses with ⌘⇧M.")
                )
            }
        }
        .frame(minWidth: 280)
    }

    private struct Summary {
        let headline: [String]
        let changes: [JSONDiff.Change]
        let markdown: String
    }

    private var summary: Summary? {
        guard let leftRaw, let rightRaw,
              let a = try? JSONValue(data: leftRaw),
              let b = try? JSONValue(data: rightRaw) else { return nil }
        let decoder = JWSDecoder()
        let decodedA = decoder.decodeTree(a)
        let decodedB = decoder.decodeTree(b)
        let differ = JSONDiff()
        let changes = differ.diff(decodedA, decodedB)
        return Summary(
            headline: differ.summarize(changes),
            changes: changes,
            markdown: differ.renderMarkdown(changes)
        )
    }

    private func pretty(_ raw: Data?) -> String {
        guard let raw, let value = try? JSONValue(data: raw) else { return "(no payload)" }
        return value.encodePretty()
    }
}

struct DiffRow: View {
    let change: JSONDiff.Change

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            badge
            VStack(alignment: .leading, spacing: 2) {
                Text(change.path.pretty)
                    .font(.system(.caption, design: .monospaced))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var badge: some View {
        Text(letter)
            .font(.caption2.weight(.bold))
            .frame(width: 18, height: 18)
            .background(color.opacity(0.16), in: Circle())
            .foregroundStyle(color)
    }

    private var letter: String {
        switch change {
        case .added: return "+"
        case .removed: return "−"
        case .changed: return "~"
        }
    }

    private var color: Color {
        switch change {
        case .added: return .green
        case .removed: return .red
        case .changed: return .orange
        }
    }

    private var detail: String {
        switch change {
        case let .added(_, value):
            return value.encodeCompact()
        case let .removed(_, value):
            return value.encodeCompact()
        case let .changed(_, from, to):
            return "\(from.encodeCompact()) → \(to.encodeCompact())"
        }
    }
}
