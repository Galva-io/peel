import XCTest
@testable import PeelCore

final class AuthErrorMapperTests: XCTestCase {
    func testAgreementsHint() {
        let diag = AuthErrorMapper.diagnose(status: 401, body: #"{"errorCode":"NOT_AUTHORIZED","errorMessage":"please review your agreements"}"#)
        XCTAssertEqual(diag?.title, "Pending agreements in App Store Connect")
    }

    func testWrongKeyTypeHint() {
        let diag = AuthErrorMapper.diagnose(status: 401, body: #"{"errorCode":"NOT_AUTHORIZED"}"#)
        XCTAssertEqual(diag?.title, "Token rejected — wrong key type or bad claims")
    }

    func testRateLimitedHint() {
        XCTAssertEqual(AuthErrorMapper.diagnose(status: 429, body: "")?.title, "Rate limited")
    }

    func testServerErrorHint() {
        XCTAssertEqual(AuthErrorMapper.diagnose(status: 502, body: "")?.title, "Apple-side error")
    }

    func testNo404Hint() {
        // 404 with a non-transaction body should not fabricate a hint.
        XCTAssertNil(AuthErrorMapper.diagnose(status: 404, body: "{\"foo\":\"bar\"}"))
    }
}
