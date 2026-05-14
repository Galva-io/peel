import Foundation

/// Minimal HTTP/1.1 request parser. Apple's server notifications only ever
/// send `POST` with a JSON body, but we accept any method here to keep the
/// parser useful for ad-hoc local testing too.
public enum HTTPParser {
    public struct Request: Sendable {
        public let method: String
        public let path: String
        public let httpVersion: String
        public let headers: [String: String]
        public let body: Data
    }

    public static func parse(data: Data) -> Request? {
        guard let separator = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = data.subdata(in: 0..<separator.lowerBound)
        let body = data.subdata(in: separator.upperBound..<data.count)
        guard let headString = String(data: head, encoding: .utf8) else { return nil }
        let lines = headString.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 3 else { return nil }
        let method = String(parts[0])
        let path = String(parts[1])
        let version = String(parts[2])
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { continue }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }
        return Request(method: method, path: path, httpVersion: version, headers: headers, body: body)
    }
}
