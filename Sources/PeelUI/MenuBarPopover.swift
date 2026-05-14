import SwiftUI
import PeelCore

public struct MenuBarPopover: View {
    @Bindable public var store: PeelAppStore
    @State private var transactionId: String = ""

    public init(store: PeelAppStore) { self.store = store }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick lookup").font(.headline)
            HStack(spacing: 6) {
                TextField("Transaction ID", text: $transactionId)
                    .textFieldStyle(.roundedBorder)
                Button("Open") { openLookup() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(transactionId.isEmpty)
            }

            if !store.history.isEmpty {
                Divider()
                Text("Recent").font(.caption).foregroundStyle(.secondary)
                ForEach(store.history.prefix(5)) { record in
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(record.responseStatus < 300 ? .green : .orange)
                            .imageScale(.small)
                        Text(record.endpoint.displayName).font(.caption)
                        Spacer()
                        Text(record.sentAt, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
            Button("Open Peel") {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private func openLookup() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(
            name: .peelOpenFromMenuBar,
            object: transactionId
        )
        transactionId = ""
    }
}

extension Notification.Name {
    public static let peelOpenFromMenuBar = Notification.Name("io.galva.peel.openFromMenuBar")
}
