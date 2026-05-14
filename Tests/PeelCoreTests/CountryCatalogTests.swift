import XCTest
@testable import PeelCore

final class CountryCatalogTests: XCTestCase {
    func testCatalogContainsCommonCountries() {
        let codes = CountryCatalog.all.map(\.code)
        XCTAssertTrue(codes.contains("US"))
        XCTAssertTrue(codes.contains("GB"))
        XCTAssertTrue(codes.contains("JP"))
        XCTAssertTrue(codes.contains("VN"))
    }

    func testSearchByName() {
        let results = CountryCatalog.search("united")
        XCTAssertTrue(results.contains(where: { $0.code == "US" }))
        XCTAssertTrue(results.contains(where: { $0.code == "GB" }))
    }

    func testSearchByCodePrefix() {
        let results = CountryCatalog.search("US")
        XCTAssertTrue(results.contains(where: { $0.code == "US" }))
    }

    func testFlagEmojiBuilder() {
        let us = CountryCatalog.country(forCode: "US")
        XCTAssertEqual(us?.flag, "🇺🇸")
        let jp = CountryCatalog.country(forCode: "JP")
        XCTAssertEqual(jp?.flag, "🇯🇵")
    }

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(CountryCatalog.country(forCode: "us")?.code, "US")
        XCTAssertEqual(CountryCatalog.country(forCode: "us")?.flag, "🇺🇸")
    }
}
