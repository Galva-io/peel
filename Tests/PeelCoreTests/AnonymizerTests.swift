import XCTest
@testable import PeelCore

final class AnonymizerTests: XCTestCase {
    func testRedactsKnownKeys() throws {
        let value = try JSONValue(string: #"{"transactionId":"tx","appAccountToken":"abc","status":1}"#)
        let anonymized = Anonymizer().anonymize(value)
        XCTAssertEqual(anonymized["transactionId"]?.stringValue, "<redacted>")
        XCTAssertEqual(anonymized["appAccountToken"]?.stringValue, "<redacted>")
        XCTAssertNotEqual(anonymized["status"]?.numberValue?.literal, "<redacted>")
    }

    func testHandlesNestedStructures() throws {
        let value = try JSONValue(string: #"{"data":[{"email":"a@example.com"}]}"#)
        let anonymized = Anonymizer().anonymize(value)
        guard case let .array(items) = anonymized["data"]!,
              case let .object(pairs) = items[0] else {
            return XCTFail("expected structure preserved")
        }
        XCTAssertEqual(pairs.first(where: { $0.key == "email" })?.value, .string("<redacted>"))
    }

    func testRedactsSignedJWSStringsByPrefix() throws {
        let value = try JSONValue(string: #"{"signedPayload":"a.b.c","status":1}"#)
        let anonymized = Anonymizer().anonymize(value)
        XCTAssertEqual(anonymized["signedPayload"]?.stringValue, "<redacted>")
    }
}
