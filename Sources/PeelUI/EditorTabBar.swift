import SwiftUI
import PeelCore
import PeelAPI

/// Two stacked strips above the request editor — the tab strip and the
/// breadcrumb / jump bar, exactly as Xcode does. The tab strip carries the
/// current "document" (endpoint); the breadcrumb shows where it sits in
/// the navigation (app › category › endpoint). Both strips are slim, use
/// system-12pt and 11pt typography, and sit against `.bar` material so
/// they blend with the toolbar above.
struct EditorTabBar: View {
    @Bindable var store: PeelAppStore
    let endpoint: EndpointID

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider()
            breadcrumb
            Divider()
        }
        .background(.bar)
    }

    // MARK: - Tab strip

    private var tabStrip: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: glyphForEndpoint)
                    .imageScale(.small)
                    .foregroundStyle(endpoint.isMutating ? AnyShapeStyle(PeelTheme.productionTint) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                Text(endpoint.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                Rectangle()
                    .fill(.background)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(.tint).frame(height: 1)
                    }
            )
            .overlay(alignment: .trailing) {
                Rectangle().fill(.separator).frame(width: 0.5)
            }

            Spacer()
        }
        .frame(height: 26)
    }

    private var glyphForEndpoint: String {
        switch endpoint.httpMethod {
        case .get: return "arrow.down.circle"
        case .post: return "paperplane"
        case .put: return "pencil"
        }
    }

    // MARK: - Breadcrumb / jump bar

    private var breadcrumb: some View {
        HStack(spacing: 0) {
            crumb(text: store.activeApp?.displayName ?? "Peel", weight: .semibold)
            chevron
            crumb(text: endpoint.category.displayName, weight: .regular)
            chevron
            crumb(text: endpoint.displayName, weight: .medium, foreground: .primary)
            Spacer()
            methodChip
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
    }

    private func crumb(text: String, weight: Font.Weight, foreground: Color? = nil) -> some View {
        Text(text)
            .font(.system(size: 11, weight: weight))
            .foregroundStyle(foreground ?? .secondary)
            .lineLimit(1)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .imageScale(.small)
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
    }

    /// Tiny method indicator on the trailing side of the breadcrumb. Matches
    /// Xcode's "scope" pill on its jump bar.
    private var methodChip: some View {
        Text(endpoint.httpMethod.label)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.3)
            .foregroundStyle(endpoint.isMutating ? PeelTheme.productionTint : .secondary)
    }
}
