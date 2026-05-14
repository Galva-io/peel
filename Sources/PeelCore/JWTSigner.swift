import Foundation
import CryptoKit

/// ES256 JWT signer for App Store Server API tokens.
///
/// Tokens follow Apple's required shape:
///
///     header  = { "alg": "ES256", "kid": <Key ID>, "typ": "JWT" }
///     payload = { "iss": <Issuer ID>, "iat": <now>, "exp": <now + ttl>,
///                 "aud": "appstoreconnect-v1", "bid": <Bundle ID> }
///
/// `exp` must be at most one hour after `iat`. Peel defaults to 20 minutes so
/// developers can keep a window open all day without re-signing every request,
/// while staying well under Apple's ceiling if their clock skews slightly.
public struct JWTSigner: Sendable {
    public struct Claims: Sendable {
        public let issuerId: String
        public let keyId: String
        public let bundleId: String
        public let issuedAt: Date
        public let expiresAt: Date

        public init(
            issuerId: String,
            keyId: String,
            bundleId: String,
            issuedAt: Date,
            expiresAt: Date
        ) {
            self.issuerId = issuerId
            self.keyId = keyId
            self.bundleId = bundleId
            self.issuedAt = issuedAt
            self.expiresAt = expiresAt
        }
    }

    public static let defaultTTL: TimeInterval = 20 * 60
    public static let maxTTL: TimeInterval = 60 * 60
    public static let audience = "appstoreconnect-v1"

    public init() {}

    public func sign(claims: Claims, with privateKey: P256.Signing.PrivateKey) throws -> String {
        guard claims.expiresAt.timeIntervalSince(claims.issuedAt) <= Self.maxTTL + 1 else {
            throw PeelError.validation("JWT lifetime must be at most one hour")
        }
        guard claims.expiresAt > claims.issuedAt else {
            throw PeelError.validation("JWT expiration must be in the future")
        }

        let header: [String: String] = [
            "alg": "ES256",
            "kid": claims.keyId,
            "typ": "JWT"
        ]
        let payload: [String: Any] = [
            "iss": claims.issuerId,
            "iat": Int(claims.issuedAt.timeIntervalSince1970),
            "exp": Int(claims.expiresAt.timeIntervalSince1970),
            "aud": Self.audience,
            "bid": claims.bundleId
        ]

        let headerData = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])

        let signingInput = "\(Base64URL.encode(headerData)).\(Base64URL.encode(payloadData))"
        guard let signingBytes = signingInput.data(using: .utf8) else {
            throw PeelError.decoding("Could not encode JWT signing input")
        }

        let signature = try privateKey.signature(for: signingBytes)
        return "\(signingInput).\(Base64URL.encode(signature.rawRepresentation))"
    }

    /// Convenience: sign with a freshly-issued claim block using the default
    /// TTL (20 minutes from `now`).
    public func sign(
        issuerId: String,
        keyId: String,
        bundleId: String,
        privateKey: P256.Signing.PrivateKey,
        now: Date = Date(),
        ttl: TimeInterval = JWTSigner.defaultTTL
    ) throws -> String {
        let claims = Claims(
            issuerId: issuerId,
            keyId: keyId,
            bundleId: bundleId,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(ttl)
        )
        return try sign(claims: claims, with: privateKey)
    }
}

/// Lightweight in-memory cache so we don't re-sign a JWT on every request to
/// the same app. We refresh well before Apple's hard expiry to avoid clock
/// skew issues.
public actor JWTCache {
    public struct Token: Sendable {
        public let value: String
        public let expiresAt: Date
        public let issuedAt: Date
        public init(value: String, expiresAt: Date, issuedAt: Date) {
            self.value = value
            self.expiresAt = expiresAt
            self.issuedAt = issuedAt
        }
    }

    private var tokens: [UUID: Token] = [:]
    private let refreshLeeway: TimeInterval

    public init(refreshLeeway: TimeInterval = 120) {
        self.refreshLeeway = refreshLeeway
    }

    public func token(for appId: UUID, now: Date = Date()) -> Token? {
        guard let existing = tokens[appId] else { return nil }
        if existing.expiresAt.timeIntervalSince(now) > refreshLeeway {
            return existing
        }
        tokens[appId] = nil
        return nil
    }

    public func store(_ token: Token, for appId: UUID) {
        tokens[appId] = token
    }

    public func evict(_ appId: UUID) {
        tokens[appId] = nil
    }

    public func evictAll() {
        tokens.removeAll()
    }
}
