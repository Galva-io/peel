import Foundation

/// Configuration for a single App Store Connect app context.
///
/// Persisted as a SwiftData entity in `PeelPersistence`. The `.p8` key itself
/// is **never** stored here — only its Keychain reference. See `KeychainStore`.
public struct AppConfig: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var displayName: String
    public var bundleId: String
    public var issuerId: String
    public var keyId: String
    public var environmentSupport: AppEnvironmentSupport
    public var accentColorHex: String
    public var isPinned: Bool
    public var sortOrder: Int
    public var createdAt: Date
    /// PNG bytes fetched from the iTunes Lookup API. Kept inline because the
    /// 100/512px artwork Apple serves is well under 100 KB.
    public var iconData: Data?

    public init(
        id: UUID = UUID(),
        displayName: String,
        bundleId: String,
        issuerId: String,
        keyId: String,
        environmentSupport: AppEnvironmentSupport = .both,
        accentColorHex: String = "#0A84FF",
        isPinned: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        iconData: Data? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.bundleId = bundleId
        self.issuerId = issuerId
        self.keyId = keyId
        self.environmentSupport = environmentSupport
        self.accentColorHex = accentColorHex
        self.isPinned = isPinned
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.iconData = iconData
    }

    public var keychainAccount: String { "\(id.uuidString).p8" }
}

/// Validates the structural shape of identifiers users paste in. Apple does not
/// publish a formal grammar, but Issuer IDs and Key IDs have stable forms.
public enum AppConfigValidator {
    public static func validateBundleId(_ value: String) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalid("Bundle ID is required") }
        guard trimmed.contains(".") else {
            return .invalid("Bundle IDs are reverse-DNS — e.g. com.example.app")
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return .invalid("Use only letters, digits, dots, and hyphens")
        }
        return .valid
    }

    public static func validateIssuerId(_ value: String) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalid("Issuer ID is required") }
        // Apple Issuer IDs are UUIDs.
        guard UUID(uuidString: trimmed) != nil else {
            return .invalid("Issuer ID looks like a UUID — check App Store Connect → Users and Access → Keys")
        }
        return .valid
    }

    public static func validateKeyId(_ value: String) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalid("Key ID is required") }
        guard trimmed.count == 10 else {
            return .invalid("Key IDs are 10 characters — check the .p8 filename")
        }
        guard trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            return .invalid("Use only letters and digits")
        }
        return .valid
    }
}

public enum ValidationResult: Equatable, Sendable {
    case valid
    case invalid(String)

    public var isValid: Bool { self == .valid }
    public var message: String? {
        if case let .invalid(m) = self { return m }
        return nil
    }
}
