import Foundation

/// Plain-English labels for well-known App Store Server API fields. Used by
/// the response viewer's HTML renderer to annotate fields like `status` or
/// `expiresDate` with what they mean, in line with the source value. Add new
/// entries as Apple ships new fields.
public enum SemanticFieldDescriptions {
    public static let labels: [String: String] = [
        "appAccountToken": "Developer-supplied user ID for the purchase",
        "autoRenewStatus": "1 = on, 0 = off",
        "bundleId": "App's bundle identifier",
        "currency": "ISO-4217 currency code",
        "environment": "Apple-supplied environment label",
        "expiresDate": "Epoch ms when this period ends",
        "inAppOwnershipType": "Family Sharing ownership type",
        "originalTransactionId": "Stable ID for the entire subscription chain",
        "price": "Price in micro-units",
        "productId": "App Store product identifier",
        "purchaseDate": "Epoch ms when the purchase was made",
        "quantity": "Number of items purchased",
        "revocationDate": "Epoch ms when the purchase was revoked",
        "revocationReason": "0 = other, 1 = refund",
        "signedDate": "Epoch ms when Apple signed the payload",
        "status": "1 active, 2 expired, 3 in billing retry, 4 in grace period, 5 revoked",
        "subscriptionGroupIdentifier": "Subscription group ID",
        "transactionId": "Unique ID for this transaction",
        "type": "Product type (Auto-Renewable, Non-Consumable, etc.)",
        "webOrderLineItemId": "Cross-storefront stable ID for a renewal"
    ]

    public static func label(for key: String) -> String? { labels[key] }
}
