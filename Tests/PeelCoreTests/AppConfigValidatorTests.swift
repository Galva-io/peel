import XCTest
@testable import PeelCore

final class AppConfigValidatorTests: XCTestCase {
    func testBundleId() {
        XCTAssertTrue(AppConfigValidator.validateBundleId("com.example.app").isValid)
        XCTAssertFalse(AppConfigValidator.validateBundleId("").isValid)
        XCTAssertFalse(AppConfigValidator.validateBundleId("nodots").isValid)
        XCTAssertFalse(AppConfigValidator.validateBundleId("com.example.app!").isValid)
    }

    func testIssuerId() {
        XCTAssertTrue(AppConfigValidator.validateIssuerId(UUID().uuidString).isValid)
        XCTAssertFalse(AppConfigValidator.validateIssuerId("123").isValid)
    }

    func testKeyId() {
        XCTAssertTrue(AppConfigValidator.validateKeyId("ABCDEFGHIJ").isValid)
        XCTAssertFalse(AppConfigValidator.validateKeyId("short").isValid)
        XCTAssertFalse(AppConfigValidator.validateKeyId("ABCDEFGHI!").isValid)
    }
}
