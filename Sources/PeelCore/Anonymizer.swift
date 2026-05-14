import Foundation

/// PII redactor for "share anonymized" exports.
///
/// Walks a `JSONValue` tree and replaces sensitive fields with stable
/// placeholders. The set of redacted keys covers everything Apple emits that
/// can identify a customer (App Account Token, email, custom data) plus
/// developer secrets (the raw signed JWS strings themselves, which contain
/// the bundle ID and Issuer ID).
public struct Anonymizer: Sendable {
    public struct Options: Sendable {
        public var redactedKeys: Set<String>
        public var redactedKeySuffixes: [String]
        public var redactedKeyPrefixes: [String]
        public var keepStructure: Bool

        public static let `default` = Options(
            redactedKeys: [
                "appAccountToken",
                "email",
                "customerEmail",
                "customData",
                "deviceVerification",
                "deviceVerificationNonce",
                "originalTransactionId",
                "transactionId",
                "webOrderLineItemId",
                "appleSignedDate",
                "raw"
            ],
            redactedKeySuffixes: ["Token", "Email", "Id", "ID"],
            redactedKeyPrefixes: ["signed"],
            keepStructure: true
        )

        public init(
            redactedKeys: Set<String>,
            redactedKeySuffixes: [String],
            redactedKeyPrefixes: [String],
            keepStructure: Bool
        ) {
            self.redactedKeys = redactedKeys
            self.redactedKeySuffixes = redactedKeySuffixes
            self.redactedKeyPrefixes = redactedKeyPrefixes
            self.keepStructure = keepStructure
        }
    }

    public let options: Options
    public init(options: Options = .default) { self.options = options }

    public func anonymize(_ value: JSONValue) -> JSONValue {
        switch value {
        case let .object(pairs):
            return .object(pairs.map { pair in
                if shouldRedact(key: pair.key) {
                    return JSONValue.Pair(pair.key, redactedReplacement(for: pair.value))
                }
                return JSONValue.Pair(pair.key, anonymize(pair.value))
            })
        case let .array(items):
            return .array(items.map(anonymize))
        default:
            return value
        }
    }

    private func shouldRedact(key: String) -> Bool {
        if options.redactedKeys.contains(key) { return true }
        if options.redactedKeyPrefixes.contains(where: { key.hasPrefix($0) }) { return true }
        if options.redactedKeySuffixes.contains(where: { key.hasSuffix($0) }) { return true }
        return false
    }

    private func redactedReplacement(for value: JSONValue) -> JSONValue {
        guard options.keepStructure else { return .string("<redacted>") }
        switch value {
        case .string: return .string("<redacted>")
        case .number: return .string("<redacted>")
        case .bool, .null: return value
        case .array: return .array([.string("<redacted>")])
        case .object: return .object([JSONValue.Pair("<redacted>", .string("<redacted>"))])
        }
    }
}
