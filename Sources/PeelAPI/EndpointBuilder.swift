import Foundation
import PeelCore

/// Converts validated user input into an `EndpointSpec`. Keeps URL templating
/// and body serialization out of UI code.
public enum EndpointBuilder {
    public static func build(
        endpoint: EndpointID,
        parameters: RequestParameters
    ) throws -> EndpointSpec {
        switch endpoint {
        case .getAllSubscriptionStatuses:
            return EndpointSpec(
                id: endpoint, method: .get,
                pathTemplate: "/inApps/v1/subscriptions/{transactionId}",
                pathParameters: ["transactionId": try required(parameters, "transactionId")]
            )

        case .getTransactionInfo:
            return EndpointSpec(
                id: endpoint, method: .get,
                pathTemplate: "/inApps/v1/transactions/{transactionId}",
                pathParameters: ["transactionId": try required(parameters, "transactionId")]
            )

        case .getTransactionHistory:
            var items: [URLQueryItem] = []
            if let revision = parameters["revision"], !revision.isEmpty {
                items.append(URLQueryItem(name: "revision", value: revision))
            }
            return EndpointSpec(
                id: endpoint, method: .get,
                pathTemplate: "/inApps/v2/history/{transactionId}",
                pathParameters: ["transactionId": try required(parameters, "transactionId")],
                queryItems: items
            )

        case .lookUpOrderId:
            return EndpointSpec(
                id: endpoint, method: .get,
                pathTemplate: "/inApps/v1/lookup/{orderId}",
                pathParameters: ["orderId": try required(parameters, "orderId")]
            )

        case .sendTestNotification:
            return EndpointSpec(
                id: endpoint, method: .post,
                pathTemplate: "/inApps/v1/notifications/test"
            )

        case .getNotificationHistory:
            // `itemLimit` is Peel-internal — it controls our pagination loop
            // and never leaves the app. `paginationToken` does leave on the
            // query string, but it's hidden from the form: the store sets
            // it programmatically when fetching subsequent batches.
            var body: [String: Any] = [
                "startDate": Int(try required(parameters, "startDate")) ?? 0,
                "endDate": Int(try required(parameters, "endDate")) ?? 0
            ]
            if let t = parameters["notificationType"], !t.isEmpty { body["notificationType"] = t }
            if let id = parameters["transactionId"], !id.isEmpty { body["transactionId"] = id }
            var items: [URLQueryItem] = []
            if let p = parameters["paginationToken"], !p.isEmpty {
                items.append(URLQueryItem(name: "paginationToken", value: p))
            }
            return EndpointSpec(
                id: endpoint, method: .post,
                pathTemplate: "/inApps/v1/notifications/history",
                queryItems: items,
                body: try JSONSerialization.data(withJSONObject: body)
            )

        case .getTestNotificationStatus:
            return EndpointSpec(
                id: endpoint, method: .get,
                pathTemplate: "/inApps/v1/notifications/test/{testNotificationToken}",
                pathParameters: ["testNotificationToken": try required(parameters, "testNotificationToken")]
            )

        case .getRefundHistory:
            return EndpointSpec(
                id: endpoint, method: .get,
                pathTemplate: "/inApps/v2/refund/lookup/{transactionId}",
                pathParameters: ["transactionId": try required(parameters, "transactionId")]
            )

        case .requestRefund:
            let body: [String: Any] = [
                "refundPreference": Int(try required(parameters, "refundPreference")) ?? 0
            ]
            return EndpointSpec(
                id: endpoint, method: .put,
                pathTemplate: "/inApps/v1/transactions/consumption/{transactionId}",
                pathParameters: ["transactionId": try required(parameters, "transactionId")],
                body: try JSONSerialization.data(withJSONObject: body)
            )

        case .extendSubscriptionRenewalDate:
            let body: [String: Any] = [
                "extendByDays": Int(try required(parameters, "extendByDays")) ?? 0,
                "extendReasonCode": Int(try required(parameters, "extendReasonCode")) ?? 0,
                "requestIdentifier": UUID().uuidString
            ]
            return EndpointSpec(
                id: endpoint, method: .put,
                pathTemplate: "/inApps/v1/subscriptions/extend/{originalTransactionId}",
                pathParameters: ["originalTransactionId": try required(parameters, "originalTransactionId")],
                body: try JSONSerialization.data(withJSONObject: body)
            )

        case .extendSubscriptionRenewalDateForAllActiveSubscribers:
            var body: [String: Any] = [
                "productId": try required(parameters, "productId"),
                "extendByDays": Int(try required(parameters, "extendByDays")) ?? 0,
                "extendReasonCode": Int(try required(parameters, "extendReasonCode")) ?? 0,
                "requestIdentifier": UUID().uuidString
            ]
            if let codes = parameters["storefrontCountryCodes"], !codes.isEmpty {
                body["storefrontCountryCodes"] = codes
                    .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            return EndpointSpec(
                id: endpoint, method: .post,
                pathTemplate: "/inApps/v1/subscriptions/extend/mass",
                body: try JSONSerialization.data(withJSONObject: body)
            )

        case .getStatusOfSubscriptionRenewalDateExtensions:
            return EndpointSpec(
                id: endpoint, method: .get,
                pathTemplate: "/inApps/v1/subscriptions/extend/mass/{productId}/{requestIdentifier}",
                pathParameters: [
                    "productId": try required(parameters, "productId"),
                    "requestIdentifier": try required(parameters, "requestIdentifier")
                ]
            )

        case .setAppAccountToken:
            let body: [String: Any] = [
                "appAccountToken": try required(parameters, "appAccountToken")
            ]
            return EndpointSpec(
                id: endpoint, method: .put,
                pathTemplate: "/inApps/v1/transactions/{originalTransactionId}/appAccountToken",
                pathParameters: ["originalTransactionId": try required(parameters, "originalTransactionId")],
                body: try JSONSerialization.data(withJSONObject: body)
            )
        }
    }

    private static func required(_ params: RequestParameters, _ key: String) throws -> String {
        guard let v = params[key], !v.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw PeelError.validation("Missing required parameter '\(key)'")
        }
        return v.trimmingCharacters(in: .whitespaces)
    }
}
