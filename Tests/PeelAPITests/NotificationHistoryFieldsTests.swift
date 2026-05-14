import XCTest
@testable import PeelAPI
import PeelCore

/// Verifies the revamped `getNotificationHistory` form:
///   • paginationToken is no longer in the catalog (Peel handles it).
///   • itemLimit is exposed instead.
///   • notificationType is an enumeration sourced from `AppleNotificationType.all`.
final class NotificationHistoryFieldsTests: XCTestCase {
    func testPaginationTokenIsHidden() {
        let ids = EndpointCatalog.fields(for: .getNotificationHistory).map(\.id)
        XCTAssertFalse(ids.contains("paginationToken"))
    }

    func testItemLimitIsExposed() {
        let ids = EndpointCatalog.fields(for: .getNotificationHistory).map(\.id)
        XCTAssertTrue(ids.contains("itemLimit"))
    }

    func testNotificationTypeIsEnumeration() {
        guard let field = EndpointCatalog.fields(for: .getNotificationHistory)
                .first(where: { $0.id == "notificationType" }) else {
            return XCTFail("notificationType field missing")
        }
        if case let .enumeration(options) = field.kind {
            XCTAssertEqual(options, AppleNotificationType.all)
            XCTAssertTrue(options.contains("DID_RENEW"))
            XCTAssertTrue(options.contains("SUBSCRIBED"))
        } else {
            XCTFail("notificationType should be .enumeration")
        }
    }

    func testStartAndEndDateUseDateMillisKind() {
        let fields = EndpointCatalog.fields(for: .getNotificationHistory)
        XCTAssertEqual(fields.first(where: { $0.id == "startDate" })?.kind, .dateMillis)
        XCTAssertEqual(fields.first(where: { $0.id == "endDate" })?.kind, .dateMillis)
    }

    func testEndpointBuilderStillUsesPaginationTokenWhenSet() throws {
        // The form hides the token, but the store sets it programmatically
        // when walking the pagination chain. The builder must honor it.
        var params = RequestParameters()
        params["startDate"] = "1700000000000"
        params["endDate"] = "1701000000000"
        params["paginationToken"] = "next-page"
        let spec = try EndpointBuilder.build(endpoint: .getNotificationHistory, parameters: params)
        XCTAssertEqual(spec.queryItems, [URLQueryItem(name: "paginationToken", value: "next-page")])
    }

    func testItemLimitDoesNotLeakIntoBody() throws {
        var params = RequestParameters()
        params["startDate"] = "1700000000000"
        params["endDate"] = "1701000000000"
        params["itemLimit"] = "100"
        let spec = try EndpointBuilder.build(endpoint: .getNotificationHistory, parameters: params)
        let body = try JSONSerialization.jsonObject(with: spec.body!) as? [String: Any]
        XCTAssertNil(body?["itemLimit"], "itemLimit is Peel-internal and must not be sent to Apple")
    }
}
