import XCTest
@testable import PeelAPI
import PeelCore

/// Verifies the refund + extend forms surface coded-enum dropdowns and the
/// endpoint builder still receives integer wire values.
final class CodedEnumTests: XCTestCase {
    func testRefundPreferenceIsCodedEnum() {
        guard let field = EndpointCatalog.fields(for: .requestRefund)
                .first(where: { $0.id == "refundPreference" }) else {
            return XCTFail("missing refundPreference field")
        }
        if case let .codedEnum(options) = field.kind {
            XCTAssertEqual(options.map(\.value), ["0", "1", "2", "3"])
            XCTAssertTrue(options.contains(where: { $0.label == "Refund Preferred" }))
        } else {
            XCTFail("expected .codedEnum")
        }
    }

    func testExtendReasonIsCodedEnumOnBothEndpoints() {
        for endpoint in [EndpointID.extendSubscriptionRenewalDate,
                         .extendSubscriptionRenewalDateForAllActiveSubscribers] {
            guard let field = EndpointCatalog.fields(for: endpoint)
                    .first(where: { $0.id == "extendReasonCode" }) else {
                XCTFail("missing extendReasonCode for \(endpoint)")
                continue
            }
            if case let .codedEnum(options) = field.kind {
                XCTAssertEqual(options.map(\.value), ["0", "1", "2", "3"])
                XCTAssertTrue(options.contains(where: { $0.label == "Customer Satisfaction" }))
            } else {
                XCTFail("\(endpoint) extendReasonCode should be .codedEnum")
            }
        }
    }

    func testStorefrontCodesIsCountryTags() {
        guard let field = EndpointCatalog.fields(for: .extendSubscriptionRenewalDateForAllActiveSubscribers)
                .first(where: { $0.id == "storefrontCountryCodes" }) else {
            return XCTFail("missing storefrontCountryCodes field")
        }
        XCTAssertEqual(field.kind, .countryCodeTags)
    }

    func testRefundBodyStillUsesIntegerWireValue() throws {
        var params = RequestParameters()
        params["transactionId"] = "1000"
        params["refundPreference"] = "1"   // string of the integer
        let spec = try EndpointBuilder.build(endpoint: .requestRefund, parameters: params)
        let body = try JSONSerialization.jsonObject(with: spec.body!) as? [String: Any]
        XCTAssertEqual(body?["refundPreference"] as? Int, 1)
    }

    func testCountryCodesParsedAsArray() throws {
        var params = RequestParameters()
        params["productId"] = "com.x.y"
        params["extendByDays"] = "30"
        params["extendReasonCode"] = "1"
        params["storefrontCountryCodes"] = "US,GB, JP"
        let spec = try EndpointBuilder.build(
            endpoint: .extendSubscriptionRenewalDateForAllActiveSubscribers,
            parameters: params
        )
        let body = try JSONSerialization.jsonObject(with: spec.body!) as? [String: Any]
        let codes = body?["storefrontCountryCodes"] as? [String]
        XCTAssertEqual(codes, ["US", "GB", "JP"])
    }
}
