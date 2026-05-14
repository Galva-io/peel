import Foundation

/// Stable identifiers for every App Store Server API endpoint Peel speaks.
///
/// New endpoints should be added here first; the UI iterates over `allCases`
/// when building the endpoint picker.
public enum EndpointID: String, CaseIterable, Codable, Sendable, Identifiable {
    // Subscription & transaction reads
    case getAllSubscriptionStatuses
    case getTransactionInfo
    case getTransactionHistory
    case lookUpOrderId

    // Notifications
    case sendTestNotification
    case getNotificationHistory
    case getTestNotificationStatus

    // Refunds
    case getRefundHistory

    // Mutating (gated by read-only toggle)
    case requestRefund
    case extendSubscriptionRenewalDate
    case extendSubscriptionRenewalDateForAllActiveSubscribers
    case getStatusOfSubscriptionRenewalDateExtensions

    // Identity
    case setAppAccountToken

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .getAllSubscriptionStatuses: return "Get All Subscription Statuses"
        case .getTransactionInfo: return "Get Transaction Info"
        case .getTransactionHistory: return "Get Transaction History"
        case .lookUpOrderId: return "Look Up Order ID"
        case .sendTestNotification: return "Send Test Notification"
        case .getNotificationHistory: return "Get Notification History"
        case .getTestNotificationStatus: return "Get Test Notification Status"
        case .getRefundHistory: return "Get Refund History"
        case .requestRefund: return "Request Refund (Consumer)"
        case .extendSubscriptionRenewalDate: return "Extend Subscription Renewal Date"
        case .extendSubscriptionRenewalDateForAllActiveSubscribers: return "Extend Renewal Date (All Subscribers)"
        case .getStatusOfSubscriptionRenewalDateExtensions: return "Get Status of Renewal Date Extensions"
        case .setAppAccountToken: return "Set App Account Token"
        }
    }

    public var category: Category {
        switch self {
        case .getAllSubscriptionStatuses, .getTransactionInfo, .getTransactionHistory, .lookUpOrderId:
            return .subscriptions
        case .sendTestNotification, .getNotificationHistory, .getTestNotificationStatus:
            return .notifications
        case .getRefundHistory:
            return .refunds
        case .requestRefund, .extendSubscriptionRenewalDate,
             .extendSubscriptionRenewalDateForAllActiveSubscribers,
             .getStatusOfSubscriptionRenewalDateExtensions, .setAppAccountToken:
            return .mutating
        }
    }

    public var isMutating: Bool {
        switch self {
        case .requestRefund, .extendSubscriptionRenewalDate,
             .extendSubscriptionRenewalDateForAllActiveSubscribers, .setAppAccountToken:
            return true
        default:
            return false
        }
    }

    /// HTTP verb this endpoint hits. Surfaces in the sidebar as a colored
    /// badge (GET=read, PUT/POST=write) so users can see at a glance what a
    /// row will do.
    public var httpMethod: HTTPMethod {
        switch self {
        case .getAllSubscriptionStatuses, .getTransactionInfo, .getTransactionHistory,
             .lookUpOrderId, .getTestNotificationStatus, .getRefundHistory,
             .getStatusOfSubscriptionRenewalDateExtensions:
            return .get
        case .sendTestNotification, .getNotificationHistory,
             .extendSubscriptionRenewalDateForAllActiveSubscribers:
            return .post
        case .requestRefund, .extendSubscriptionRenewalDate, .setAppAccountToken:
            return .put
        }
    }

    public enum HTTPMethod: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"

        public var label: String { rawValue }
    }

    public var docsURL: URL {
        let slug: String
        switch self {
        case .getAllSubscriptionStatuses: slug = "get_all_subscription_statuses"
        case .getTransactionInfo: slug = "get_transaction_info"
        case .getTransactionHistory: slug = "get_transaction_history_v2"
        case .lookUpOrderId: slug = "look_up_order_id"
        case .sendTestNotification: slug = "request_a_test_notification"
        case .getNotificationHistory: slug = "get_notification_history"
        case .getTestNotificationStatus: slug = "get_test_notification_status"
        case .getRefundHistory: slug = "get_refund_history_v2"
        case .requestRefund: slug = "send_consumption_information"
        case .extendSubscriptionRenewalDate: slug = "extend_a_subscription_renewal_date"
        case .extendSubscriptionRenewalDateForAllActiveSubscribers: slug = "extend_subscription_renewal_dates_for_all_active_subscribers"
        case .getStatusOfSubscriptionRenewalDateExtensions: slug = "get_status_of_subscription_renewal_date_extensions"
        case .setAppAccountToken: slug = "set_app_account_token"
        }
        return URL(string: "https://developer.apple.com/documentation/appstoreserverapi/\(slug)")!
    }

    public enum Category: String, Sendable, CaseIterable {
        case subscriptions
        case notifications
        case refunds
        case mutating

        public var displayName: String {
            switch self {
            case .subscriptions: return "Subscriptions & Transactions"
            case .notifications: return "Notifications"
            case .refunds: return "Refunds"
            case .mutating: return "Mutating Actions"
            }
        }
    }
}
