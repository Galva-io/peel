import Foundation
import PeelCore

/// A pre-dispatch confirmation prompt for a mutating endpoint. The
/// `RequestPanel` builds one of these whenever the user clicks Send on a
/// destructive call and presents it to the user before letting the
/// request leave the app. The descriptor carries:
///
///   • A plain-English title and body that explains what's about to
///     happen — not just the endpoint name, but the customer-facing
///     consequence ("Apple may refund the customer's purchase").
///   • A parameter table the user can scan: app, environment, the actual
///     wire values, with the Production row highlighted so it never
///     blends into the others.
///   • A severity. `.critical` paints the icon and confirm button red and
///     is reserved for Production calls and mass operations; `.warning`
///     uses the orange triangle and a neutral accent.
public struct EndpointConfirmation: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let endpoint: EndpointID
    public let title: String
    public let body: String
    public let parameters: [Row]
    public let severity: Severity
    public let confirmButtonTitle: String

    public struct Row: Sendable, Hashable {
        public let label: String
        public let value: String
        public let isWarning: Bool

        public init(label: String, value: String, isWarning: Bool = false) {
            self.label = label
            self.value = value
            self.isWarning = isWarning
        }
    }

    public enum Severity: Sendable, Hashable {
        case warning
        case critical
    }

    public init(
        id: UUID = UUID(),
        endpoint: EndpointID,
        title: String,
        body: String,
        parameters: [Row],
        severity: Severity,
        confirmButtonTitle: String
    ) {
        self.id = id
        self.endpoint = endpoint
        self.title = title
        self.body = body
        self.parameters = parameters
        self.severity = severity
        self.confirmButtonTitle = confirmButtonTitle
    }
}

public enum EndpointConfirmationBuilder {
    /// Returns a confirmation descriptor for any endpoint that mutates
    /// state. Non-mutating endpoints fire without a prompt; this returns
    /// `nil` for those.
    public static func describe(
        endpoint: EndpointID,
        parameters: RequestParameters,
        environment: APIEnvironment,
        appName: String
    ) -> EndpointConfirmation? {
        guard endpoint.isMutating else { return nil }

        let severity = severity(for: endpoint, environment: environment)
        let envRow = EndpointConfirmation.Row(
            label: "Environment",
            value: environment.displayName,
            isWarning: environment == .production
        )

        switch endpoint {
        case .requestRefund:
            let txId = parameters["transactionId"] ?? "—"
            let pref = parameters["refundPreference"] ?? "0"
            let prefLabel = AppleEnumValues.refundPreference.first(where: { $0.value == pref })?.label ?? pref
            return EndpointConfirmation(
                endpoint: endpoint,
                title: "Request refund?",
                body: "Apple will review a refund request for this transaction. If approved, the customer receives a refund and the transaction is reversed. Apple's decision is final.",
                parameters: [
                    .init(label: "App", value: appName),
                    envRow,
                    .init(label: "Transaction ID", value: txId),
                    .init(label: "Refund Preference", value: prefLabel)
                ],
                severity: severity,
                confirmButtonTitle: "Send Refund Request"
            )

        case .extendSubscriptionRenewalDate:
            let txId = parameters["originalTransactionId"] ?? "—"
            let days = parameters["extendByDays"] ?? "—"
            let reason = parameters["extendReasonCode"] ?? "0"
            let reasonLabel = AppleEnumValues.extendReason.first(where: { $0.value == reason })?.label ?? reason
            return EndpointConfirmation(
                endpoint: endpoint,
                title: "Extend renewal date?",
                body: "This pushes the next renewal date out by \(days) day\(days == "1" ? "" : "s") for one subscriber. They'll be billed later than originally scheduled. The change cannot be reversed except by another extension.",
                parameters: [
                    .init(label: "App", value: appName),
                    envRow,
                    .init(label: "Original Tx ID", value: txId),
                    .init(label: "Extend By", value: "\(days) day\(days == "1" ? "" : "s")"),
                    .init(label: "Reason", value: reasonLabel)
                ],
                severity: severity,
                confirmButtonTitle: "Extend Renewal"
            )

        case .extendSubscriptionRenewalDateForAllActiveSubscribers:
            let productId = parameters["productId"] ?? "—"
            let days = parameters["extendByDays"] ?? "—"
            let reason = parameters["extendReasonCode"] ?? "0"
            let reasonLabel = AppleEnumValues.extendReason.first(where: { $0.value == reason })?.label ?? reason
            let rawCodes = parameters["storefrontCountryCodes"] ?? ""
            let codeList = rawCodes
                .split(separator: ",", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let storefrontDesc = codeList.isEmpty ? "Every storefront" : codeList.joined(separator: ", ")
            return EndpointConfirmation(
                endpoint: endpoint,
                title: "Extend renewal for every active subscriber?",
                body: "This affects every active subscriber of \(productId)\(codeList.isEmpty ? "" : " in the chosen storefronts"). Apple processes the bulk extension asynchronously. It cannot be undone in bulk — only via per-subscriber calls.",
                parameters: [
                    .init(label: "App", value: appName),
                    envRow,
                    .init(label: "Product ID", value: productId),
                    .init(label: "Extend By", value: "\(days) day\(days == "1" ? "" : "s")"),
                    .init(label: "Reason", value: reasonLabel),
                    .init(label: "Storefronts", value: storefrontDesc, isWarning: codeList.isEmpty)
                ],
                // Mass operations are always critical, even in sandbox —
                // the operator should pause before any "for all
                // subscribers" call lands.
                severity: .critical,
                confirmButtonTitle: "Extend All Subscribers"
            )

        case .setAppAccountToken:
            let txId = parameters["originalTransactionId"] ?? "—"
            let token = parameters["appAccountToken"] ?? "—"
            return EndpointConfirmation(
                endpoint: endpoint,
                title: "Set App Account Token?",
                body: "Attaches an App Account Token to this transaction, linking the purchase to your internal user identifier. No customer-visible effect; useful for reconciling purchases against your own user records.",
                parameters: [
                    .init(label: "App", value: appName),
                    envRow,
                    .init(label: "Original Tx ID", value: txId),
                    .init(label: "App Account Token", value: token)
                ],
                severity: severity,
                confirmButtonTitle: "Set Token"
            )

        default:
            return nil
        }
    }

    private static func severity(
        for endpoint: EndpointID,
        environment: APIEnvironment
    ) -> EndpointConfirmation.Severity {
        if environment == .production { return .critical }
        if endpoint == .extendSubscriptionRenewalDateForAllActiveSubscribers { return .critical }
        return .warning
    }
}
