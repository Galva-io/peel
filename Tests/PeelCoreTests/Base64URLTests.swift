import XCTest
@testable import PeelCore

final class Base64URLTests: XCTestCase {
    func testRoundTrip() {
        let original = "Hello, Peel — 🍎"
        let data = Data(original.utf8)
        let encoded = Base64URL.encode(data)
        XCTAssertFalse(encoded.contains("="))
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
        let decoded = Base64URL.decode(encoded)
        XCTAssertEqual(decoded, data)
    }

    func testHandlesPaddingFreeInputs() {
        let raw = "abc".data(using: .utf8)!
        let encoded = raw.base64EncodedString().trimmingCharacters(in: CharacterSet(charactersIn: "="))
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        XCTAssertEqual(Base64URL.decode(encoded), raw)
    }
}
