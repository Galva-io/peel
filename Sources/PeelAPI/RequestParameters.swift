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
        /// An enum that ships a human label alongside its wire value.
        /// Used for things like Apple's `extendReasonCode` where the API
        /// expects `1` but users think "Customer Satisfaction."
        case codedEnum(options: [CodedOption])
        /// Multi-select tag picker for ISO 3166-1 alpha-2 storefront
        /// codes. Stored as a comma-separated string in `RequestParameters`.
        case countryCodeTags
    }

    /// One option in a `codedEnum`: a user-facing `label` and the actual
    /// wire `value` that gets sent to Apple. Stored as a struct (not a
    /// tuple) so `Kind` stays `Hashable`.
    public struct CodedOption: Sendable, Hashable, Identifiable {
        public let label: String
        public let value: String
        public var id: String { value }
        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
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
        case .text, .longText, .enumeration, .countryCodeTags:
            return .valid
        case let .codedEnum(options):
            return options.contains(where: { $0.value == value }) ? .valid : .invalid("Invalid option")
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
                ParameterField(id: "refundPreference", label: "Refund Preference",
                               kind: .codedEnum(options: AppleEnumValues.refundPreference),
                               isRequired: true,
                               help: "Tells Apple which outcome you'd prefer for this refund.")
            ]
        case .extendSubscriptionRenewalDate:
            return [
                ParameterField(id: "originalTransactionId", label: "Original Transaction ID", kind: .transactionId, isRequired: true),
                ParameterField(id: "extendByDays", label: "Extend By (Days)", kind: .integer, isRequired: true,
                               placeholder: "30"),
                ParameterField(id: "extendReasonCode", label: "Reason",
                               kind: .codedEnum(options: AppleEnumValues.extendReason),
                               isRequired: true,
                               help: "Why you're extending the renewal date.")
            ]
        case .extendSubscriptionRenewalDateForAllActiveSubscribers:
            return [
                ParameterField(id: "productId", label: "Product ID", kind: .text, isRequired: true),
                ParameterField(id: "extendByDays", label: "Extend By (Days)", kind: .integer, isRequired: true),
                ParameterField(id: "extendReasonCode", label: "Reason",
                               kind: .codedEnum(options: AppleEnumValues.extendReason),
                               isRequired: true,
                               help: "Why you're extending the renewal date."),
                ParameterField(id: "storefrontCountryCodes", label: "Storefronts",
                               kind: .countryCodeTags,
                               isRequired: false,
                               help: "Leave empty to target every storefront.")
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
