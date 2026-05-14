import XCTest
@testable import PeelWebhook

final class HTTPParserTests: XCTestCase {
    func testParsesPostWithJsonBody() {
        let raw = "POST /webhook HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: 13\r\n\r\n{\"hello\":1}"
        guard let req = HTTPParser.parse(data: Data(raw.utf8)) else {
            return XCTFail("did not parse")
        }
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.path, "/webhook")
        XCTAssertEqual(req.headers["Content-Type"], "application/json")
        XCTAssertEqual(String(data: req.body, encoding: .utf8), "{\"hello\":1}")
    }

    func testReturnsNilOnMalformedRequest() {
        XCTAssertNil(HTTPParser.parse(data: Data("garbage".utf8)))
    }
}
