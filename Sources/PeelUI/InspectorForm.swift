import SwiftUI

/// Inspector-style form vocabulary, modeled on Xcode's File Inspector and
/// Build Settings layouts:
///
///   ▸ Section header is 11-pt uppercase tracked semibold with a 0.5-pt
///     underline. Always reads as the structural divider.
///   ▸ Row is a horizontal pair: right-aligned 11-pt secondary label in a
///     fixed column, control in the trailing column. Help and error sit
///     under the control, indented to align.
///
/// All forms in Peel — request panel, Add App sheet, anywhere else — share
/// this vocabulary so the chrome feels like one app.
enum InspectorFormMetrics {
    /// Fixed pixel width for the leading label column. Matches Xcode's
    /// File Inspector label gutter so the eye lands on the same vertical
    /// line every section.
    static let labelColumnWidth: CGFloat = 124
    static let rowSpacing: CGFloat = 6
    static let sectionSpacing: CGFloat = 18
    static let labelToControlSpacing: CGFloat = 10
}

/// A titled group of rows. Use one per logical block of fields — Xcode does
/// "Identity", "Deployment Info", "Frameworks, Libraries, and Embedded
/// Content", etc. We keep our titles short and Title Case.
struct InspectorFormSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorFormMetrics.rowSpacing) {
            sectionHeader
            content
        }
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Rectangle()
                .fill(.separator)
                .frame(height: 0.5)
        }
        .padding(.bottom, 2)
    }
}

/// One field row: label on the left, control on the right, optional help
/// and inline error stacked below the control. The label column is fixed
/// so rows align across sections.
struct InspectorFormRow<Content: View>: View {
    let label: String
    var isRequired: Bool = false
    var help: String? = nil
    var error: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: InspectorFormMetrics.labelToControlSpacing) {
            HStack(spacing: 2) {
                Spacer(minLength: 0)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if isRequired {
                    Text("✱")
                        .font(.system(size: 9))
                        .foregroundStyle(PeelTheme.productionTint)
                }
            }
            .frame(width: InspectorFormMetrics.labelColumnWidth, alignment: .trailing)

            VStack(alignment: .leading, spacing: 3) {
                content()
                if let error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(PeelTheme.productionTint)
                        .lineLimit(2)
                } else if let help {
                    Text(help)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Action row pinned at the bottom of a form: primary action trailing,
/// optional ⋯ overflow menu. Aligns to the value column so it sits on the
/// same axis as the controls above.
struct InspectorFormActions<Trailing: View>: View {
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: InspectorFormMetrics.labelToControlSpacing) {
            Spacer().frame(width: InspectorFormMetrics.labelColumnWidth)
            HStack(spacing: 8) {
                trailing()
            }
        }
    }
}
