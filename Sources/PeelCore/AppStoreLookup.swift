import Foundation

/// Calls the public iTunes Lookup API (`https://itunes.apple.com/lookup`) to
/// resolve an App Store URL or bundle id into display metadata: app name,
/// bundle id, and artwork. This is the same endpoint App Store badges and
/// link previews use; no authentication required and no rate-limit headers
/// documented (be sensible).
///
/// We treat the response as best-effort. If the lookup fails the Add App
/// sheet simply falls back to manual entry.
public actor AppStoreLookup {
    public struct AppMetadata: Sendable, Equatable {
        public let bundleId: String
        public let name: String
        public let artworkURL: URL?
        public let storeURL: URL?
    }

    public enum Failure: Error, Equatable {
        case notFound
        case badResponse
        case network(String)
    }

    public protocol Transport: Sendable {
        func get(_ url: URL) async throws -> Data
    }

    public struct URLSessionTransport: Transport {
        public let session: URLSession
        public init(session: URLSession = URLSession(configuration: .ephemeral)) {
            self.session = session
        }
        public func get(_ url: URL) async throws -> Data {
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw Failure.badResponse
                }
                return data
            } catch let error as Failure {
                throw error
            } catch {
                throw Failure.network(error.localizedDescription)
            }
        }
    }

    private let transport: Transport
    private let allowlist: Set<String>
    /// In-memory cache so repeated lookups (e.g. typing a bundle id) only hit
    /// the network once per identifier.
    private var cache: [String: AppMetadata] = [:]

    public init(transport: Transport = URLSessionTransport(), allowlist: Set<String> = NetworkAllowlist.hosts) {
        self.transport = transport
        self.allowlist = allowlist
    }

    // MARK: - Public entry points

    public func lookup(bundleId: String) async throws -> AppMetadata {
        if let cached = cache[bundleId] { return cached }
        let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(percent(bundleId))&limit=1")!
        return try await fetchAndCache(url)
    }

    public func lookup(appId: String) async throws -> AppMetadata {
        if let cached = cache[appId] { return cached }
        let url = URL(string: "https://itunes.apple.com/lookup?id=\(percent(appId))&limit=1")!
        return try await fetchAndCache(url)
    }

    /// Accepts a paste from Safari's address bar:
    ///
    ///     https://apps.apple.com/us/app/foo/id1234567890
    ///     https://apps.apple.com/app/id1234567890
    ///
    /// Extracts the numeric `id` and looks it up.
    public func lookup(url string: String) async throws -> AppMetadata {
        guard let id = Self.extractAppID(from: string) else {
            throw Failure.notFound
        }
        return try await lookup(appId: id)
    }

    /// Strips the trailing `id<digits>` slug from any App Store URL Apple
    /// produces. Exposed for tests.
    public static func extractAppID(from string: String) -> String? {
        // Tolerant: also accept a bare `id1234567890` or just digits.
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = UInt64(trimmed) { return String(direct) }
        // Look for `idNNNN` anywhere.
        if let range = trimmed.range(of: #"id\d+"#, options: .regularExpression) {
            return String(trimmed[range].dropFirst(2))
        }
        return nil
    }

    /// Downloads the raw artwork bytes for caching alongside the app config.
    public func downloadArtwork(_ url: URL) async throws -> Data {
        guard allowlist.contains(url.host ?? "") else {
            throw Failure.network("Host not on allowlist: \(url.host ?? "?")")
        }
        return try await transport.get(url)
    }

    // MARK: - Internal

    private func fetchAndCache(_ url: URL) async throws -> AppMetadata {
        guard allowlist.contains(url.host ?? "") else {
            throw Failure.network("Host not on allowlist: \(url.host ?? "?")")
        }
        let data = try await transport.get(url)
        let value = try JSONValue(data: data)
        guard let results = value["results"]?.arrayValue, let first = results.first else {
            throw Failure.notFound
        }
        guard let bundleId = first["bundleId"]?.stringValue,
              let name = first["trackName"]?.stringValue else {
            throw Failure.notFound
        }
        let artwork = (first["artworkUrl512"]?.stringValue ?? first["artworkUrl100"]?.stringValue ?? first["artworkUrl60"]?.stringValue)
            .flatMap(URL.init(string:))
        let store = first["trackViewUrl"]?.stringValue.flatMap(URL.init(string:))
        let metadata = AppMetadata(bundleId: bundleId, name: name, artworkURL: artwork, storeURL: store)
        cache[bundleId] = metadata
        if let trackId = first["trackId"]?.numberValue?.literal {
            cache[trackId] = metadata
        }
        return metadata
    }

    private func percent(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}
