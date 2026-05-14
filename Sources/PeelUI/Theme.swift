import SwiftUI
import AppKit

/// Centralized design tokens. Production-tinted chrome is everywhere; this is
/// where we keep the canonical color so nothing drifts.
public enum PeelTheme {
    public static let productionTint = Color(red: 0.83, green: 0.18, blue: 0.18)
    public static let sandboxTint = Color(red: 0.18, green: 0.55, blue: 0.30)

    public static func tint(for environment: PeelEnvironmentDescriptor) -> Color {
        switch environment {
        case .production: return productionTint
        case .sandbox: return sandboxTint
        }
    }
}

public enum PeelEnvironmentDescriptor: Sendable, Hashable {
    case sandbox
    case production
}

extension Color {
    /// Parses `#RRGGBB` strings stored in `AppConfig.accentColorHex`.
    public init?(hex: String) {
        var value = hex
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let int = UInt64(value, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
