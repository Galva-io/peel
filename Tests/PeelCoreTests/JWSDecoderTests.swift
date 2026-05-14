import XCTest
import CryptoKit
@testable import PeelCore

final class JWSDecoderTests: XCTestCase {
    func testDecodesNestedSignedFields() throws {
        let inner: [String: Any] = ["transactionId": "tx_123", "status": 1]
        let innerData = try JSONSerialization.data(withJSONObject: inner, options: [.sortedKeys])
        let jws = try makeJWS(headerJSON: ["alg": "ES256"], payload: innerData)

        let body: [String: Any] = [
            "data": [
                ["signedTransactionInfo": jws]
            ]
        ]
        let raw = try JSONSerialization.data(withJSONObject: body)
        let value = try JSONValue(data: raw)
        let decoded = JWSDecoder().decodeTree(value)

        // Walk to the decoded JWS envelope.
        guard case let .object(top) = decoded,
              let dataValue = top.first(where: { $0.key == "data" })?.value,
              case let .array(items) = dataValue,
              case let .object(first) = items[0],
              let envelope = first.first(where: { $0.key == "signedTransactionInfo" })?.value,
              case let .object(envelopePairs) = envelope else {
            return XCTFail("could not walk decoded tree")
        }
        XCTAssertEqual(envelopePairs.first(where: { $0.key == "__peel_jws" })?.value, .bool(true))
        let payload = envelopePairs.first(where: { $0.key == "payload" })?.value
        XCTAssertEqual(payload?["transactionId"]?.stringValue, "tx_123")
    }

    func testIgnoresStringsThatLookSimilarButArentJWS() throws {
        let body: [String: Any] = ["notes": "signed by hand, just text"]
        let raw = try JSONSerialization.data(withJSONObject: body)
        let decoded = try JWSDecoder().decodeTree(raw)
        XCTAssertEqual(decoded["notes"]?.stringValue, "signed by hand, just text")
    }

    func testDecodeOneSurfacesX5cPresence() throws {
        let jwsWithChain = try makeJWS(
            headerJSON: ["alg": "ES256", "x5c": ["cert1", "cert2"]],
            payload: Data(#"{"a":1}"#.utf8)
        )
        let decoded = try JWSDecoder().decodeOne(jws: jwsWithChain)
        XCTAssertTrue(decoded.x5cPresent)
    }

    // MARK: helpers

    private func makeJWS(headerJSON: [String: Any], payload: Data) throws -> String {
        let header = try JSONSerialization.data(withJSONObject: headerJSON, options: [.sortedKeys])
        let signature = Data(repeating: 0, count: 64)
        return [
            Base64URL.encode(header),
            Base64URL.encode(payload),
            Base64URL.encode(signature)
        ].joined(separator: ".")
    }
}
