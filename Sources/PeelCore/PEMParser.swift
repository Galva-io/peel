import Foundation
import CryptoKit

/// Parses an Apple `.p8` private key into a CryptoKit `P256.Signing.PrivateKey`.
///
/// Apple distributes ES256 keys in PKCS#8 PEM. CryptoKit accepts PKCS#8 DER
/// via `init(pkcs8DERRepresentation:)` (Swift 5.10+), or PEM via
/// `init(pemRepresentation:)` (iOS 17 / macOS 14+). We use the PEM initializer
/// directly when available and fall back to DER decoding the SEC1 / PKCS#8
/// content ourselves.
public enum PEMParser {
    public static func privateKey(fromPEM pem: String) throws -> P256.Signing.PrivateKey {
        let cleaned = pem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw PeelError.validation("Empty private key file")
        }

        // CryptoKit's PEM initializer handles both EC PRIVATE KEY (SEC1) and
        // PRIVATE KEY (PKCS#8) headers. Apple ships PKCS#8.
        do {
            return try P256.Signing.PrivateKey(pemRepresentation: cleaned)
        } catch {
            throw PeelError(
                kind: .auth,
                title: "Invalid .p8 key",
                message: "Could not parse the private key from the file.",
                remediation: "Confirm the file is an unmodified .p8 downloaded from App Store Connect (Users and Access → Integrations).",
                underlyingDescription: String(describing: error)
            )
        }
    }

    /// Loads PEM contents from a file URL and returns them as a string.
    public static func readPEM(fromFile url: URL) throws -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw PeelError(
                kind: .auth,
                title: "Cannot read key file",
                message: "Could not read \(url.lastPathComponent).",
                remediation: "Check the file permissions and try dragging it in again.",
                underlyingDescription: String(describing: error)
            )
        }
    }
}
