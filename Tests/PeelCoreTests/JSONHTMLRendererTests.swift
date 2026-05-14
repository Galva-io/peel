import XCTest
@testable import PeelCore

final class JSONHTMLRendererTests: XCTestCase {
    func testRendersSimpleObject() throws {
        let value = try JSONValue(string: #"{"name":"Alice","age":30}"#)
        let html = JSONHTMLRenderer().render(value)
        XCTAssertTrue(html.contains("\"Alice\""))
        XCTAssertTrue(html.contains("<span class=\"key\">name</span>"))
        XCTAssertTrue(html.contains("<span class=\"val num\">30</span>"))
    }

    func testRendersArray() throws {
        let value = try JSONValue(string: "[1,2,3]")
        let html = JSONHTMLRenderer().render(value)
        XCTAssertTrue(html.contains("<details class=\"arr\""))
        XCTAssertTrue(html.contains("[3 items]"))
    }

    func testRendersJWSEnvelopeBadge() throws {
        let value = try JSONValue(string: #"{"__peel_jws":true,"header":{"alg":"ES256"},"payload":{"txn":"1"}}"#)
        let html = JSONHTMLRenderer().render(value)
        XCTAssertTrue(html.contains("decoded JWS"))
        XCTAssertTrue(html.contains("jws"))
    }

    func testEscapesHTML() throws {
        let value = try JSONValue(string: #"{"x":"<script>alert(1)</script>"}"#)
        let html = JSONHTMLRenderer().render(value)
        XCTAssertFalse(html.contains("<script>alert(1)</script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    func testIncludesSemanticHintForKnownFields() throws {
        let value = try JSONValue(string: #"{"status":1}"#)
        let html = JSONHTMLRenderer().render(value)
        XCTAssertTrue(html.contains("1 active, 2 expired"))
    }

    func testInitiallyClosedBeyondDepth() throws {
        // Object nested 6 deep; with `initiallyOpenDepth: 1`, only the outer
        // object should have `open` attribute on its details.
        let inner = try JSONValue(string: "{\"a\":{\"b\":{\"c\":{\"d\":{\"e\":1}}}}}")
        let html = JSONHTMLRenderer(options: .init(initiallyOpenDepth: 1)).render(inner)
        let openCount = html.components(separatedBy: " open>").count - 1
        // 1 open details (outer) — anything deeper should be closed.
        XCTAssertEqual(openCount, 1)
    }

    func testRendersFastForLargeArrays() throws {
        // Performance smoke test: 5,000 small transactions in <50 ms.
        var items: [String] = []
        for i in 0..<5_000 {
            items.append("{\"transactionId\":\"\(i)\",\"status\":1}")
        }
        let json = "[" + items.joined(separator: ",") + "]"
        let value = try JSONValue(string: json)
        let start = Date()
        let html = JSONHTMLRenderer().render(value)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(html.count, 5_000)
        XCTAssertLessThan(elapsed, 0.5, "renderer took \(Int(elapsed * 1000))ms — expected < 500ms")
    }
}
