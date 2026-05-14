import XCTest
import CryptoKit
@testable import PeelCore

final class JWTSignerTests: XCTestCase {
    func testGeneratedTokenHasThreeSegmentsAndExpectedHeader() throws {
        let key = P256.Signing.PrivateKey()
        let signer = JWTSigner()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = try signer.sign(
            issuerId: "1234-5678-9abc-def0",
            keyId: "ABCDEFGHIJ",
            bundleId: "com.example.app",
            privateKey: key,
            now: now
        )
        let parts = token.split(separator: ".")
        XCTAssertEqual(parts.count, 3)

        guard let headerData = Base64URL.decode(String(parts[0])),
              let header = try JSONSerialization.jsonObject(with: headerData) as? [String: String] else {
            return XCTFail("could not decode header")
        }
        XCTAssertEqual(header["alg"], "ES256")
        XCTAssertEqual(header["kid"], "ABCDEFGHIJ")
        XCTAssertEqual(header["typ"], "JWT")

        guard let payloadData = Base64URL.decode(String(parts[1])),
              let payload = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return XCTFail("could not decode payload")
        }
        XCTAssertEqual(payload["aud"] as? String, "appstoreconnect-v1")
        XCTAssertEqual(payload["bid"] as? String, "com.example.app")
        XCTAssertEqual(payload["iss"] as? String, "1234-5678-9abc-def0")
        XCTAssertEqual((payload["iat"] as? Int).map(TimeInterval.init), now.timeIntervalSince1970)
    }

    func testRejectsExcessiveTTL() throws {
        let key = P256.Signing.PrivateKey()
        let signer = JWTSigner()
        XCTAssertThrowsError(try signer.sign(
            issuerId: "1", keyId: "2", bundleId: "3",
            privateKey: key,
            now: Date(),
            ttl: 24 * 60 * 60
        ))
    }

    func testSignatureRoundTripsThroughVerifier() throws {
        let key = P256.Signing.PrivateKey()
        let publicKey = key.publicKey
        let signer = JWTSigner()
        let token = try signer.sign(
            issuerId: "iss",
            keyId: "kid",
            bundleId: "bid",
            privateKey: key
        )
        let parts = token.split(separator: ".")
        let signingInput = "\(parts[0]).\(parts[1])".data(using: .utf8)!
        let signature = Base64URL.decode(String(parts[2]))!
        XCTAssertTrue(publicKey.isValidSignature(
            try P256.Signing.ECDSASignature(rawRepresentation: signature),
            for: signingInput
        ))
    }

    func testCacheRefreshesNearExpiry() async {
        let cache = JWTCache(refreshLeeway: 60)
        let now = Date()
        let token = JWTCache.Token(value: "abc", expiresAt: now.addingTimeInterval(120), issuedAt: now)
        await cache.store(token, for: UUID())
        let appId = UUID()
        await cache.store(token, for: appId)
        let fresh = await cache.token(for: appId, now: now)
        XCTAssertEqual(fresh?.value, "abc")
        let aboutToExpire = await cache.token(for: appId, now: now.addingTimeInterval(80))
        XCTAssertNil(aboutToExpire)
    }
}
