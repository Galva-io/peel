import Foundation

/// Hard-coded list of hosts Peel is permitted to contact. Any other request
/// is failed-closed before it leaves the app. The trust contract with users is
/// that nothing leaves their machine except calls to Apple (and Sparkle for
/// updates if they opt in to telemetry / updates).
public enum NetworkAllowlist {
    public static let hosts: Set<String> = [
        "api.storekit.itunes.apple.com",
        "api.storekit-sandbox.itunes.apple.com",
        "itunes.apple.com",           // public App Store metadata lookup (icon, name)
        "is1-ssl.mzstatic.com",       // CDN that serves the App Store artwork
        "is2-ssl.mzstatic.com",
        "is3-ssl.mzstatic.com",
        "is4-ssl.mzstatic.com",
        "is5-ssl.mzstatic.com",
        "developer.apple.com",        // docs links opened in browser, not in-app
        "update.peel-app.com",        // Sparkle appcast
        "crash.peel-app.com"          // telemetry endpoint (opt-in only)
    ]

    public static func isAllowed(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return hosts.contains(host)
    }
}
