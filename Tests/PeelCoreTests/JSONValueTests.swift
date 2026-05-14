import XCTest
@testable import PeelCore

final class JSONValueTests: XCTestCase {
    func testParsePreservesKeyOrder() throws {
        let raw = #"{"b":1,"a":2,"z":{"k":"v"}}"#
        let value = try JSONValue(string: raw)
        guard case let .object(pairs) = value else { return XCTFail("expected object") }
        XCTAssertEqual(pairs.map(\.key), ["b", "a", "z"])
    }

    func testParseNestedAndArrays() throws {
        let raw = #"{"items":[1,2,{"nested":true}],"flag":null}"#
        let value = try JSONValue(string: raw)
        XCTAssertNotNil(value["items"])
        guard case let .array(items) = value["items"]! else { return XCTFail() }
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(value["flag"], .null)
    }

    func testPrettyEncodeRoundTrip() throws {
        let raw = #"{"transactionId":"123","autoRenewStatus":1,"price":4990000}"#
        let value = try JSONValue(string: raw)
        let pretty = value.encodePretty()
        let reparsed = try JSONValue(string: pretty)
        XCTAssertEqual(value, reparsed)
    }

    func testUnicodeEscapes() throws {
        let value = try JSONValue(string: #""é""#)
        XCTAssertEqual(value.stringValue, "é")
    }
}
