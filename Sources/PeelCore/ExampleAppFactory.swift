import Foundation
import CryptoKit

/// Builds a fake `AppConfig` + matching `.p8` PEM so a fresh user can drop
/// the app into the sidebar and explore the form vocabulary without
/// providing real App Store Connect credentials.
///
/// The generated ES256 key is genuine — it'll satisfy `PEMParser` and Peel
/// will happily sign JWTs with it. Apple will of course reject those
/// tokens at the network edge, which is itself useful: the user sees a
/// real 401 with our `AuthErrorMapper` diagnosis attached, making the
/// example self-explanatory.
public enum ExampleAppFactory {
    /// Stable bundle id so we can detect whether the demo is already in
    /// place and avoid creating duplicates.
    public static let bundleId = "com.peel.example"

    public static let displayName = "Example App"
    public static let issuerId = "00000000-0000-0000-0000-000000000000"
    public static let keyId = "PEELEXAMPL"

    /// Returns the `AppConfig` describing the demo app and a freshly
    /// generated ES256 private key in PEM form. Each call generates a new
    /// key — that's fine, we never need to reproduce signatures.
    public static func make() -> (config: AppConfig, pem: String) {
        let key = P256.Signing.PrivateKey()
        let pem = key.pemRepresentation
        let config = AppConfig(
            displayName: displayName,
            bundleId: bundleId,
            issuerId: issuerId,
            keyId: keyId,
            environmentSupport: .sandboxOnly,
            accentColorHex: "#5E5CE6"
        )
        return (config, pem)
    }
}
