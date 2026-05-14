import Foundation
import PeelCore

/// Network client for the App Store Server API. Owns the JWT cache,
/// constructs `URLRequest`s, and translates Apple's responses into
/// `APIResponse` envelopes.
///
/// The client is environment-agnostic — callers pass an `APIEnvironment` per
/// request. This way one client instance serves both sandbox and production
/// from a single app context.
public actor Client {
    public struct Settings: Sendable {
        public var session: URLSessionConfiguration
        public var userAgent: String
        public var jwtTTL: TimeInterval
        public var allowlist: Set<String>

        public init(
            session: URLSessionConfiguration = .ephemeral,
            userAgent: String = "Peel/1.0 (https://peel-app.com)",
            jwtTTL: TimeInterval = JWTSigner.defaultTTL,
            allowlist: Set<String> = NetworkAllowlist.hosts
        ) {
            self.session = session
            self.userAgent = userAgent
            self.jwtTTL = jwtTTL
            self.allowlist = allowlist
        }
    }

    public protocol KeyFetcher: Sendable {
        func fetch(account: String) throws -> String
    }

    public struct DispatchInput: Sendable {
        public let appConfig: AppConfig
        public let environment: APIEnvironment
        public let spec: EndpointSpec
        public let readOnly: Bool

        public init(appConfig: AppConfig, environment: APIEnvironment, spec: EndpointSpec, readOnly: Bool) {
            self.appConfig = appConfig
            self.environment = environment
            self.spec = spec
            self.readOnly = readOnly
        }
    }

    public struct APIResponse: Sendable {
        public let request: URLRequest
        public let status: Int
        public let body: Data
        public let headers: [String: String]
        public let durationMs: Int
        public let jwt: String
        public let diagnosis: AuthErrorMapper.Diagnosis?

        public init(
            request: URLRequest,
            status: Int,
            body: Data,
            headers: [String: String],
            durationMs: Int,
            jwt: String,
            diagnosis: AuthErrorMapper.Diagnosis? = nil
        ) {
            self.request = request
            self.status = status
            self.body = body
            self.headers = headers
            self.durationMs = durationMs
            self.jwt = jwt
            self.diagnosis = diagnosis
        }

        public var isSuccess: Bool { (200..<300).contains(status) }
    }

    public protocol Transport: Sendable {
        func send(_ request: URLRequest) async throws -> (Data, URLResponse)
    }

    private let settings: Settings
    private let keyFetcher: KeyFetcher
    private let transport: Transport
    private let signer = JWTSigner()
    private let cache: JWTCache

    public init(
        settings: Settings = Settings(),
        keyFetcher: KeyFetcher,
        transport: Transport = URLSessionTransport()
    ) {
        self.settings = settings
        self.keyFetcher = keyFetcher
        self.transport = transport
        self.cache = JWTCache()
    }

    public func dispatch(_ input: DispatchInput) async throws -> APIResponse {
        if input.readOnly && input.spec.id.isMutating {
            throw PeelError(
                kind: .validation,
                title: "Read-only mode is on",
                message: "Peel is in read-only mode. Mutating endpoints are disabled.",
                remediation: "Toggle read-only off in the toolbar (⌘⌃R) to enable mutating calls.",
                underlyingDescription: nil
            )
        }

        let url = input.spec.url(in: input.environment)
        guard settings.allowlist.contains(url.host ?? "") else {
            throw PeelError(
                kind: .sandbox,
                title: "Blocked by allowlist",
                message: "Peel only contacts Apple's servers. \(url.host ?? "(no host)") is not in the allowlist.",
                remediation: "If you're a contributor adding a new host, update NetworkAllowlist.hosts.",
                underlyingDescription: nil
            )
        }

        let jwt = try await currentJWT(for: input.appConfig)

        var request = URLRequest(url: url)
        request.httpMethod = input.spec.method.rawValue
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue(settings.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = input.spec.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let started = Date()
        do {
            let (data, response) = try await transport.send(request)
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            guard let http = response as? HTTPURLResponse else {
                throw PeelError.network("Non-HTTP response")
            }

            let headers = http.allHeaderFields.reduce(into: [String: String]()) { acc, pair in
                if let k = pair.key as? String { acc[k] = "\(pair.value)" }
            }

            let bodyString = String(data: data, encoding: .utf8) ?? ""
            let diagnosis = AuthErrorMapper.diagnose(status: http.statusCode, body: bodyString)

            // Auth failed: drop the cached token so the next call regenerates.
            if http.statusCode == 401 {
                await cache.evict(input.appConfig.id)
            }

            return APIResponse(
                request: request,
                status: http.statusCode,
                body: data,
                headers: headers,
                durationMs: durationMs,
                jwt: jwt,
                diagnosis: diagnosis
            )
        } catch let error as PeelError {
            throw error
        } catch {
            throw PeelError.network("Could not reach Apple: \(error.localizedDescription)", underlying: error)
        }
    }

    public func evictCachedJWT(for appId: UUID) async {
        await cache.evict(appId)
    }

    private func currentJWT(for app: AppConfig) async throws -> String {
        if let cached = await cache.token(for: app.id) {
            return cached.value
        }
        let pem = try keyFetcher.fetch(account: app.keychainAccount)
        let key = try PEMParser.privateKey(fromPEM: pem)
        let now = Date()
        let token = try signer.sign(
            issuerId: app.issuerId,
            keyId: app.keyId,
            bundleId: app.bundleId,
            privateKey: key,
            now: now,
            ttl: settings.jwtTTL
        )
        await cache.store(
            .init(value: token, expiresAt: now.addingTimeInterval(settings.jwtTTL), issuedAt: now),
            for: app.id
        )
        return token
    }
}

public struct URLSessionTransport: Client.Transport {
    public let session: URLSession
    public init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }
    public func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

/// Conformance adapter so callers can plug `KeychainStore` directly into the
/// client without exposing Keychain APIs to upper layers.
public struct KeychainKeyFetcher: Client.KeyFetcher {
    public let store: KeychainStore
    public init(store: KeychainStore) { self.store = store }
    public func fetch(account: String) throws -> String {
        try store.fetch(account: account)
    }
}

public struct InMemoryKeyFetcher: Client.KeyFetcher {
    public let store: InMemoryKeyStore
    public init(store: InMemoryKeyStore) { self.store = store }
    public func fetch(account: String) throws -> String {
        try store.fetch(account: account)
    }
}
