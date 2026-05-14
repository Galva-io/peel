import Foundation

/// Converts Apple's terse error responses into plain-English remediation
/// guidance. Each pattern below matches a real failure mode we've debugged.
public enum AuthErrorMapper {
    public struct Diagnosis: Sendable, Equatable {
        public let title: String
        public let body: String
        public let remediation: String
        public let docHint: String?
    }

    public static func diagnose(status: Int, body: String) -> Diagnosis? {
        let lower = body.lowercased()

        if status == 401, lower.contains("not_authorized") || lower.contains("unauthorized") {
            // Most common cause: wrong key type
            if lower.contains("agreement") {
                return Diagnosis(
                    title: "Pending agreements in App Store Connect",
                    body: "Apple rejected the request because your account has documents awaiting approval.",
                    remediation: "Sign in to App Store Connect → Agreements, Tax, and Banking and review pending items.",
                    docHint: "https://appstoreconnect.apple.com/agreements/"
                )
            }
            return Diagnosis(
                title: "Token rejected — wrong key type or bad claims",
                body: "Apple returned 401 NOT_AUTHORIZED. The most common cause is using an Admin or App Manager key instead of an In-App Purchase key.",
                remediation: """
                    1. Confirm this .p8 is an In-App Purchase key (App Store Connect → Users and Access → Integrations → App Store Server API).
                    2. Verify Issuer ID and Key ID match the .p8 file.
                    3. Check the bundle ID matches the app the key has access to.
                    """,
                docHint: "https://developer.apple.com/documentation/appstoreserverapi/generating_json_web_tokens_for_api_requests"
            )
        }

        if status == 401 {
            return Diagnosis(
                title: "Unauthorized",
                body: "Apple rejected the JWT. The token may be expired or the key may not be authorized for this endpoint.",
                remediation: "Peel auto-refreshes JWTs every 20 minutes — if you keep seeing this, regenerate the key in App Store Connect.",
                docHint: nil
            )
        }

        if status == 404, lower.contains("transaction") {
            return Diagnosis(
                title: "Transaction not found",
                body: "Apple has no record of that transaction ID in this environment.",
                remediation: "Sandbox transactions only exist in the Sandbox environment, and production transactions only exist in Production. Toggle the environment in the toolbar and try again.",
                docHint: nil
            )
        }

        if status == 429 {
            return Diagnosis(
                title: "Rate limited",
                body: "Apple is throttling requests to this endpoint.",
                remediation: "Wait 60 seconds before retrying. Apple does not publish official limits — back off aggressively in scripts.",
                docHint: nil
            )
        }

        if (500..<600).contains(status) {
            return Diagnosis(
                title: "Apple-side error",
                body: "The App Store Server API returned a server error (\(status)).",
                remediation: "This is usually transient. Retry in a minute. If it persists, check https://developer.apple.com/system-status/",
                docHint: "https://developer.apple.com/system-status/"
            )
        }

        return nil
    }
}
