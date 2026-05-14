import Foundation
import PeelCore

/// Per-endpoint form fields the UI prompts the user for. Each `Field` carries
/// its own validation. New endpoints declare their fields once here and the
/// request form renders them dynamically.
public struct RequestParameters: Sendable {
    public var values: [String: String]
    public init(values: [String: String] = [:]) { self.values = values }

    public subscript(key: String) -> String? {
        get { values[key] }
        set { values[key] = newValue }
    }
}

public struct ParameterField: Sendable, Identifiable, Hashable {
    public enum Kind: Sendable, Hashable {
        case text
        case longText
        case transactionId
        case orderId
        case uuid
        case dateMillis
        case integer
        case enumeration(options: [String])
        case bool
    }

    public let id: String
    public let label: String
    public let kind: Kind
    public let isRequired: Bool
    public let placeholder: String?
    public let help: String?

    public init(
        id: String,
        label: String,
        kind: Kind,
        isRequired: Bool = false,
        placeholder: String? = nil,
        help: String? = nil
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.isRequired = isRequired
        self.placeholder = placeholder
        self.help = help
    }

    public func validate(_ raw: String?) -> ValidationResult {
        let value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            return isRequired ? .invalid("\(label) is required") : .valid
        }
        switch kind {
        case .text, .longText, .enumeration:
            return .valid
        case .transactionId, .orderId, .integer:
            return value.allSatisfy(\.isNumber) ? .valid : .invalid("\(label) must be digits only")
        case .uuid:
            return UUID(uuidString: value) != nil ? .valid : .invalid("\(label) must be a UUID")
        case .dateMillis:
            return Int(value) != nil ? .valid : .invalid("\(label) must be epoch milliseconds")
        case .bool:
            let lower = value.lowercased()
            return ["true", "false", "1", "0"].contains(lower) ? .valid : .invalid("\(label) must be true or false")
        }
    }
}

public enum EndpointCatalog {
    public static func fields(for id: EndpointID) -> [ParameterField] {
        switch id {
        case .getAllSubscriptionStatuses:
            return [
                ParameterField(id: "transactionId", label: "Transaction ID", kind: .transactionId, isRequired: true,
                               placeholder: "1000000000000000",
                               help: "Original transaction ID or any transaction ID in the chain.")
            ]
        case .getTransactionInfo:
            return [
                ParameterField(id: "transactionId", label: "Transaction ID", kind: .transactionId, isRequired: true)
            ]
        case .getTransactionHistory:
            return [
                ParameterField(id: "transactionId", label: "Transaction ID", kind: .transactionId, isRequired: true),
                ParameterField(id: "revision", label: "Revision", kind: .text, isRequired: false,
                               help: "Paginate by passing the value returned in the previous response.")
            ]
        case .lookUpOrderId:
            return [
                ParameterField(id: "orderId", label: "Order ID", kind: .text, isRequired: true,
                               placeholder: "FAKEORDER",
                               help: "12-character order ID from the customer's purchase receipt.")
            ]
        case .sendTestNotification:
            return []
        case .getNotificationHistory:
            return [
                ParameterField(id: "startDate", label: "Start date", kind: .dateMillis, isRequired: true,
                               help: "Inclusive lower bound of the time window."),
                ParameterField(id: "endDate", label: "End date", kind: .dateMillis, isRequired: true,
                               help: "Inclusive upper bound."),
                ParameterField(id: "notificationType", label: "Notification type",
                               kind: .enumeration(options: AppleNotificationType.all), isRequired: false,
                               help: "Leave empty to match every type."),
                ParameterField(id: "transactionId", label: "Transaction ID", kind: .transactionId, isRequired: false,
                               help: "Optional filter. Suggestions are pulled from your prior requests."),
                ParameterField(id: "itemLimit", label: "How many to fetch", kind: .integer, isRequired: false,
                               placeholder: "20",
                               help: "Peel paginates automatically until it hits this count or runs out of results.")
            ]
        case .getTestNotificationStatus:
            return [
                ParameterField(id: "testNotificationToken", label: "Test notification token", kind: .text, isRequired: true,
                               help: "Returned by sendTestNotification.")
            ]
        case .getRefundHistory:
            return [
                ParameterField(id: "transactionId", label: "Transaction ID", kind: .transactionId, isRequired: true),
                ParameterField(id: "revision", label: "Revision", kind: .text, isRequired: false)
            ]
        case .requestRefund:
            return [
                ParameterField(id: "transactionId", label: "Transaction ID", kind: .transactionId, isRequired: true),
                ParameterField(id: "refundPreference", label: "Refund preference", kind: .integer, isRequired: true,
                               placeholder: "0",
                               help: "0 = undeclared, 1 = preferred, 2 = not preferred, 3 = no preference.")
            ]
        case .extendSubscriptionRenewalDate:
            return [
                ParameterField(id: "originalTransactionId", label: "Original transaction ID", kind: .transactionId, isRequired: true),
                ParameterField(id: "extendByDays", label: "Extend by (days)", kind: .integer, isRequired: true,
                               placeholder: "30"),
                ParameterField(id: "extendReasonCode", label: "Reason code", kind: .integer, isRequired: true,
                               help: "0 = undeclared, 1 = customer satisfaction, 2 = other, 3 = service issue, 4 = other.")
            ]
        case .extendSubscriptionRenewalDateForAllActiveSubscribers:
            return [
                ParameterField(id: "productId", label: "Product ID", kind: .text, isRequired: true),
                ParameterField(id: "extendByDays", label: "Extend by (days)", kind: .integer, isRequired: true),
                ParameterField(id: "extendReasonCode", label: "Reason code", kind: .integer, isRequired: true),
                ParameterField(id: "storefrontCountryCodes", label: "Storefront country codes (comma-separated)", kind: .text, isRequired: false)
            ]
        case .getStatusOfSubscriptionRenewalDateExtensions:
            return [
                ParameterField(id: "productId", label: "Product ID", kind: .text, isRequired: true),
                ParameterField(id: "requestIdentifier", label: "Request identifier", kind: .text, isRequired: true)
            ]
        case .setAppAccountToken:
            return [
                ParameterField(id: "originalTransactionId", label: "Original transaction ID", kind: .transactionId, isRequired: true),
                ParameterField(id: "appAccountToken", label: "App Account Token (UUID)", kind: .uuid, isRequired: true)
            ]
        }
    }
}
