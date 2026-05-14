import Foundation

/// Full set of `notificationType` values the App Store Server Notifications
/// V2 catalog defines. Used to populate the dropdown on the
/// `getNotificationHistory` request form. Sorted alphabetically because
/// users hunt by name, not by category.
///
/// When Apple adds a new notification type, append the raw value here.
public enum AppleNotificationType {
    public static let all: [String] = [
        "CONSUMPTION_REQUEST",
        "DID_CHANGE_RENEWAL_PREF",
        "DID_CHANGE_RENEWAL_STATUS",
        "DID_FAIL_TO_RENEW",
        "DID_RENEW",
        "EXPIRED",
        "EXTERNAL_PURCHASE_TOKEN",
        "GRACE_PERIOD_EXPIRED",
        "METADATA_UPDATE",
        "MIGRATION",
        "OFFER_REDEEMED",
        "ONE_TIME_CHARGE",
        "PRICE_CHANGE",
        "PRICE_INCREASE",
        "REFUND",
        "REFUND_DECLINED",
        "REFUND_REVERSED",
        "RENEWAL_EXTENDED",
        "RENEWAL_EXTENSION",
        "REVOKE",
        "SUBSCRIBED",
        "TEST"
    ]
}
