import SwiftUI
import PeelCore
import PeelAPI

/// Pre-dispatch confirmation sheet for mutating endpoints. Mirrors the
/// shape of macOS alerts: severity icon, title, body, then a key/value
/// summary of what's about to be sent. `.critical` (production, or any
/// "for all subscribers" call) wears the production-red icon and confirm
/// button so the user can't miss it.
struct ConfirmationSheet: View {
    let confirmation: EndpointConfirmation
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Text(confirmation.body)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            VStack(spacing: 2) {
                ForEach(confirmation.parameters, id: \.self) { row in
                    ConfirmationRow(row: row)
                }
            }
            Spacer(minLength: 4)
            footer
        }
        .padding(22)
        .frame(width: 460)
        .frame(minHeight: 280)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: confirmation.severity == .critical
                  ? "exclamationmark.octagon.fill"
                  : "exclamationmark.triangle.fill")
                .font(.system(size: 26))
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(confirmation.title)
                    .font(.title3.weight(.semibold))
                Text(confirmation.endpoint.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) { onCancel() }
                .keyboardShortcut(.cancelAction)
            Button(role: .destructive) {
                onConfirm()
            } label: {
                Text(confirmation.confirmButtonTitle)
                    .frame(minWidth: 120)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(confirmation.severity == .critical ? PeelTheme.productionTint : Color.accentColor)
        }
    }

    private var iconColor: Color {
        switch confirmation.severity {
        case .critical: return PeelTheme.productionTint
        case .warning:  return .orange
        }
    }
}

/// One row in the parameter summary table. Right-aligned label gutter at
/// 130pt, monospaced value, production rows tinted red.
struct ConfirmationRow: View {
    let row: EndpointConfirmation.Row

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .trailing)
            Text(row.value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(row.isWarning ? PeelTheme.productionTint : .primary)
                .textSelection(.enabled)
            if row.isWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .imageScale(.small)
                    .foregroundStyle(PeelTheme.productionTint)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }
}
