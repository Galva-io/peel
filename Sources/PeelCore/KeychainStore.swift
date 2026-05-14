import Foundation
import Security

/// Stores `.p8` private keys in the macOS Keychain. The service identifier is
/// fixed and the account is the per-app UUID, so keys are scoped per
/// `AppConfig` and one app's compromised state never leaks to another.
public final class KeychainStore: @unchecked Sendable {
    public static let defaultService = "io.galva.peel"

    private let service: String
    /// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` keeps secrets local,
    /// not synced via iCloud Keychain, and accessible to background processes
    /// once the device has been unlocked since boot.
    private let accessibility: CFString

    public init(
        service: String = KeychainStore.defaultService,
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) {
        self.service = service
        self.accessibility = accessibility
    }

    public func store(pem: String, account: String) throws {
        guard let data = pem.data(using: .utf8) else {
            throw PeelError.keychain("Could not encode key as UTF-8")
        }
        // Delete first; SecItemUpdate has subtle attribute-matching gotchas.
        try? delete(account: account)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: accessibility,
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PeelError.keychain("Keychain save failed (OSStatus \(status))")
        }
    }

    public func fetch(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
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
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PeelError.keychain("Keychain delete failed (OSStatus \(status))")
        }
    }

    public func contains(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Used by Settings → Security → Reset Keychain access.
    public func purgeAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
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
