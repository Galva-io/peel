import XCTest
@testable import PeelAPI
import PeelCore

final class EndpointBuilderTests: XCTestCase {
    func testGetTransactionInfoURL() throws {
        var params = RequestParameters()
        params["transactionId"] = "1000000"
        let spec = try EndpointBuilder.build(endpoint: .getTransactionInfo, parameters: params)
        XCTAssertEqual(spec.method, .get)
        XCTAssertEqual(spec.resolvedPath(), "/inApps/v1/transactions/1000000")
    }

    func testTransactionHistoryAttachesRevision() throws {
        var params = RequestParameters()
        params["transactionId"] = "200"
        params["revision"] = "abc"
        let spec = try EndpointBuilder.build(endpoint: .getTransactionHistory, parameters: params)
        XCTAssertEqual(spec.queryItems, [URLQueryItem(name: "revision", value: "abc")])
    }

    func testNotificationHistorySerializesBody() throws {
        var params = RequestParameters()
        params["startDate"] = "1700000000000"
        params["endDate"] = "1701000000000"
        params["notificationType"] = "DID_RENEW"
        let spec = try EndpointBuilder.build(endpoint: .getNotificationHistory, parameters: params)
        XCTAssertEqual(spec.method, .post)
        let body = try JSONSerialization.jsonObject(with: spec.body!) as? [String: Any]
        XCTAssertEqual(body?["startDate"] as? Int, 1700000000000)
        XCTAssertEqual(body?["notificationType"] as? String, "DID_RENEW")
    }

    func testExtendRenewalGeneratesRequestIdentifier() throws {
        var params = RequestParameters()
        params["originalTransactionId"] = "1"
        params["extendByDays"] = "30"
        params["extendReasonCode"] = "1"
        let spec = try EndpointBuilder.build(endpoint: .extendSubscriptionRenewalDate, parameters: params)
        XCTAssertEqual(spec.method, .put)
        let body = try JSONSerialization.jsonObject(with: spec.body!) as? [String: Any]
        XCTAssertNotNil(body?["requestIdentifier"] as? String)
        XCTAssertEqual(body?["extendByDays"] as? Int, 30)
    }

    func testMissingRequiredFieldThrows() {
        XCTAssertThrowsError(try EndpointBuilder.build(endpoint: .getTransactionInfo, parameters: RequestParameters()))
    }
}
