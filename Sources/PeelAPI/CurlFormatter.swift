import Foundation
import PeelCore

/// Renders a `URLRequest` as a `curl` command for copy-paste sharing. We
/// preserve the exact JWT so the receiver can replay if they're authorized.
/// The UI offers an "anonymize" toggle that strips the Authorization header.
public enum CurlFormatter {
    public static func render(_ request: URLRequest, anonymize: Bool = false) -> String {
        var parts = ["curl"]
        parts.append("-X \(request.httpMethod ?? "GET")")
        if let url = request.url?.absoluteString {
            parts.append("'\(url)'")
        }
        for (header, value) in (request.allHTTPHeaderFields ?? [:]).sorted(by: { $0.key < $1.key }) {
            let v: String
            if anonymize, header.lowercased() == "authorization" {
                v = "Bearer <REDACTED>"
            } else {
                v = value
            }
            parts.append("-H '\(header): \(v)'")
        }
        if let body = request.httpBody, !body.isEmpty {
            if let pretty = String(data: body, encoding: .utf8) {
                parts.append("--data-raw '\(pretty.replacingOccurrences(of: "'", with: "'\\''"))'")
            }
        }
        return parts.joined(separator: " \\\n  ")
    }
}
