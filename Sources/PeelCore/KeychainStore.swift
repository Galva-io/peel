import Foundation
import Security

/// Stores `.p8` private keys in the macOS Keychain.
///
/// All `SecItem*` calls pass `kSecUseDataProtectionKeychain = true`, which
/// routes operations into the iOS-style **Data Protection keychain** rather
/// than the user's login keychain. This has two practical consequences:
///
///   • The OS never prompts the user for access. Items are bound to the
///     app's signing identity (Team ID + bundle id, both declared in the
///     `keychain-access-groups` entitlement) and the system permits the
///     signed Peel binary to read its own items silently.
///   • If the signing identity changes — e.g. a developer running an
///     ad-hoc-signed local build instead of the Developer-ID-signed
///     release — those items become invisible. The right tradeoff for a
///     shipped app where stable signing is the norm; contributors running
///     ad-hoc builds will simply have to re-import a `.p8`.
///
/// The service identifier is fixed (`io.galva.peel`) and each item's
/// account is the `AppConfig.id` UUID, so keys remain scoped per app.
public final class KeychainStore: @unchecked Sendable {
    public static let defaultService = "io.galva.peel"

    private let service: String
    /// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` keeps secrets
    /// local (no iCloud sync) and accessible to the app once the device
    /// has been unlocked since boot — the gentlest accessibility level
    /// that still survives reboots.
    private let accessibility: CFString

    public init(
        service: String = KeychainStore.defaultService,
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) {
        self.service = service
        self.accessibility = accessibility
    }

    /// Whether the running binary holds the `keychain-access-groups`
    /// entitlement required to talk to the Data Protection keychain.
    /// Probed once on first use and cached. Notarized release builds
    /// always set this; ad-hoc local builds (via `bundle.sh`) don't,
    /// and silently fall back to the user's login keychain so that
    /// contributor workflows still function.
    private static let dataProtectionAvailable: Bool = {
        let probeQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "__peel.probe.\(UUID().uuidString)",
            kSecUseDataProtectionKeychain as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        let status = SecItemCopyMatching(probeQuery as CFDictionary, nil)
        // errSecMissingEntitlement = -34018; surfaced when the running
        // binary lacks `keychain-access-groups`. Anything else (success,
        // not found, etc.) means the call reached the Data Protection
        // backend successfully.
        return status != -34018
    }()

    /// Shared attribute set applied to every query. Centralized so the
    /// "use the data protection keychain" flag can't accidentally be
    /// omitted from one of the call sites.
    private func baseAttributes(account: String) -> [String: Any] {
        var attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if Self.dataProtectionAvailable {
            attrs[kSecUseDataProtectionKeychain as String] = true
        }
        return attrs
    }

    public func store(pem: String, account: String) throws {
        guard let data = pem.data(using: .utf8) else {
            throw PeelError.keychain("Could not encode key as UTF-8")
        }
        // Delete first; SecItemUpdate has subtle attribute-matching gotchas.
        try? delete(account: account)

        var attributes = baseAttributes(account: account)
        attributes[kSecAttrAccessible as String] = accessibility
        attributes[kSecAttrSynchronizable as String] = false
        attributes[kSecValueData as String] = data

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PeelError.keychain("Keychain save failed (OSStatus \(status))")
        }
    }

    public func fetch(account: String) throws -> String {
        var query = baseAttributes(account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            throw PeelError.keychain("Could not load key from Keychain (OSStatus \(status))")
        }
        guard let data = item as? Data, let pem = String(data: data, encoding: .utf8) else {
            throw PeelError.keychain("Stored key is not valid UTF-8")
        }
        return pem
    }

    public func delete(account: String) throws {
        let query = baseAttributes(account: account)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PeelError.keychain("Keychain delete failed (OSStatus \(status))")
        }
    }

    public func contains(account: String) -> Bool {
        var query = baseAttributes(account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Used by Settings → Privacy → Reset Keychain access.
    public func purgeAll() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        if Self.dataProtectionAvailable {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PeelError.keychain("Keychain purge failed (OSStatus \(status))")
        }
    }
}

/// In-memory keychain stub for unit tests. Production code uses `KeychainStore`.
public final class InMemoryKeyStore: @unchecked Sendable {
    private var items: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func store(pem: String, account: String) {
        lock.lock(); defer { lock.unlock() }
        items[account] = pem
    }

    public func fetch(account: String) throws -> String {
        lock.lock(); defer { lock.unlock() }
        guard let pem = items[account] else {
            throw PeelError.keychain("No key for account \(account)")
        }
        return pem
    }

    public func delete(account: String) {
        lock.lock(); defer { lock.unlock() }
        items[account] = nil
    }

    public func contains(account: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return items[account] != nil
    }
}
