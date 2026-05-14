import Foundation

/// Base64URL encoding helpers. JWTs and JWS payloads use base64url (RFC 4648
/// §5), which is not the same as standard base64 — `+` and `/` become `-` and
/// `_`, and trailing `=` padding is dropped.
public enum Base64URL {
    public static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public static func decode(_ string: String) -> Data? {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Re-pad to a multiple of 4
        let pad = (4 - (s.count % 4)) % 4
        s.append(String(repeating: "=", count: pad))
        return Data(base64Encoded: s)
    }
}
