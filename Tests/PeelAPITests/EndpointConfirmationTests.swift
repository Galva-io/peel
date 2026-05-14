import XCTest
@testable import PeelAPI
import PeelCore

final class EndpointConfirmationTests: XCTestCase {
    func testNonMutatingEndpointReturnsNil() {
        let confirmation = EndpointConfirmationBuilder.describe(
            endpoint: .getTransactionInfo,
            parameters: RequestParameters(values: ["transactionId": "1"]),
            environment: .sandbox,
            appName: "App"
        )
        XCTAssertNil(confirmation)
    }

    func testRefundConfirmationCarriesSemanticLabels() {
        var params = RequestParameters()
        params["transactionId"] = "1000"
        params["refundPreference"] = "1"
        let confirmation = EndpointConfirmationBuilder.describe(
            endpoint: .requestRefund,
            parameters: params,
            environment: .sandbox,
            appName: "Habitify"
        )
        XCTAssertNotNil(confirmation)
        XCTAssertEqual(confirmation?.severity, .warning)
        XCTAssertTrue(confirmation?.parameters.contains(where: {
            $0.label == "Refund Preference" && $0.value == "Refund Preferred"
        }) ?? false)
        XCTAssertTrue(confirmation?.parameters.contains(where: {
            $0.label == "App" && $0.value == "Habitify"
        }) ?? false)
    }

    func testProductionFlipsSeverityToCritical() {
        var params = RequestParameters()
        params["transactionId"] = "1000"
        params["refundPreference"] = "0"
        let confirmation = EndpointConfirmationBuilder.describe(
            endpoint: .requestRefund,
            parameters: params,
            environment: .production,
            appName: "App"
        )
        XCTAssertEqual(confirmation?.severity, .critical)
        let envRow = confirmation?.parameters.first(where: { $0.label == "Environment" })
        XCTAssertEqual(envRow?.value, "Production")
        XCTAssertTrue(envRow?.isWarning ?? false)
    }

    func testMassExtendIsAlwaysCriticalEvenInSandbox() {
        var params = RequestParameters()
        params["productId"] = "com.x.y"
        params["extendByDays"] = "30"
        params["extendReasonCode"] = "1"
        let confirmation = EndpointConfirmationBuilder.describe(
            endpoint: .extendSubscriptionRenewalDateForAllActiveSubscribers,
            parameters: params,
            environment: .sandbox,
            appName: "App"
        )
        XCTAssertEqual(confirmation?.severity, .critical)
        // Empty storefronts list should highlight the "Every storefront" row.
        let storefronts = confirmation?.parameters.first(where: { $0.label == "Storefronts" })
        XCTAssertEqual(storefronts?.value, "Every storefront")
        XCTAssertTrue(storefronts?.isWarning ?? false)
    }

    func testStorefrontsFromCommaSeparatedString() {
        var params = RequestParameters()
        params["productId"] = "com.x.y"
        params["extendByDays"] = "30"
        params["extendReasonCode"] = "1"
        params["storefrontCountryCodes"] = "US, GB, JP"
        let confirmation = EndpointConfirmationBuilder.describe(
            endpoint: .extendSubscriptionRenewalDateForAllActiveSubscribers,
            parameters: params,
            environment: .sandbox,
            appName: "App"
        )
        let storefronts = confirmation?.parameters.first(where: { $0.label == "Storefronts" })
        XCTAssertEqual(storefronts?.value, "US, GB, JP")
        XCTAssertFalse(storefronts?.isWarning ?? true)
    }

    func testExtendSingleReasonLabel() {
        var params = RequestParameters()
        params["originalTransactionId"] = "1000"
        params["extendByDays"] = "1"
        params["extendReasonCode"] = "3"
        let confirmation = EndpointConfirmationBuilder.describe(
            endpoint: .extendSubscriptionRenewalDate,
            parameters: params,
            environment: .sandbox,
            appName: "App"
        )
        let reason = confirmation?.parameters.first(where: { $0.label == "Reason" })
        XCTAssertEqual(reason?.value, "Service Issue or Outage")
        let days = confirmation?.parameters.first(where: { $0.label == "Extend By" })
        XCTAssertEqual(days?.value, "1 day") // singular
    }
}
