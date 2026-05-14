import SwiftUI
import AppKit

/// Peel's color budget is deliberately tiny. Two roles:
///
///   • The system accent color (driven by the user's macOS preference, or
///     the AppIcon's AccentColor entry). Used for primary buttons, selected
///     rows, focused controls — everything an Apple-native app uses
///     `.tint` for.
///
///   • A single semantic warning red. Used **only** for Production chrome,
///     destructive confirmations, and write endpoints (which are themselves
///     destructive against live data). The point of restraint is that when
///     red appears, it means "be careful" — not "this is a tag."
///
/// Anything else (greens for sandbox, blues for POST, purples for JWS) was
/// noise and is gone.
public enum PeelTheme {
    /// Reserved for Production environment chrome and destructive UI only.
    /// Matches system red so it harmonizes with macOS alert dialogs.
    public static let warning = Color(nsColor: .systemRed)

    /// Convenience alias — kept for naming clarity in places that read
    /// "production tint" semantically rather than "warning."
    public static var productionTint: Color { warning }
}

extension Color {
    /// Parses `#RRGGBB` strings stored in `AppConfig.accentColorHex`. The
    /// per-app accent is no longer user-editable, but we still surface the
    /// stored value as a fallback for icon placeholders.
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
