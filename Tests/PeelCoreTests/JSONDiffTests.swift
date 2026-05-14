import XCTest
@testable import PeelCore

final class JSONDiffTests: XCTestCase {
    func testIdenticalProducesNoChanges() throws {
        let a = try JSONValue(string: #"{"k":"v","arr":[1,2]}"#)
        XCTAssertEqual(JSONDiff().diff(a, a), [])
    }

    func testDetectsValueChange() throws {
        let a = try JSONValue(string: #"{"status":1}"#)
        let b = try JSONValue(string: #"{"status":2}"#)
        let changes = JSONDiff().diff(a, b)
        XCTAssertEqual(changes.count, 1)
        if case let .changed(_, from, to) = changes[0] {
            XCTAssertEqual(from.numberValue?.literal, "1")
            XCTAssertEqual(to.numberValue?.literal, "2")
        } else {
            XCTFail("expected changed")
        }
    }

    func testDetectsAddAndRemove() throws {
        let a = try JSONValue(string: #"{"x":1}"#)
        let b = try JSONValue(string: #"{"y":2}"#)
        let changes = JSONDiff().diff(a, b)
        XCTAssertEqual(changes.count, 2)
    }

    func testArrayDiff() throws {
        let a = try JSONValue(string: "[1,2,3]")
        let b = try JSONValue(string: "[1,2]")
        let changes = JSONDiff().diff(a, b)
        XCTAssertEqual(changes.count, 1)
        if case let .removed(path, _) = changes[0] {
            XCTAssertEqual(path.pretty, "$[2]")
        } else {
            XCTFail("expected remove")
        }
    }

    func testRendersMarkdownTable() throws {
        let a = try JSONValue(string: #"{"expiresDate":1700000000000}"#)
        let b = try JSONValue(string: #"{"expiresDate":1702592000000}"#)
        let differ = JSONDiff()
        let changes = differ.diff(a, b)
        let md = differ.renderMarkdown(changes)
        XCTAssertTrue(md.contains("| `$.expiresDate`"))
    }
}
