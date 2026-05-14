import Foundation
import SwiftData
import PeelCore

/// SwiftData mirror of `AppConfig`. The app uses the SwiftData object as the
/// truth at the persistence boundary, but every other module passes the plain
/// `AppConfig` value so concurrency stays simple.
@Model
public final class StoredAppConfig {
    @Attribute(.unique) public var id: UUID
    public var displayName: String
    public var bundleId: String
    public var issuerId: String
    public var keyId: String
    public var environmentSupportRaw: String
    public var accentColorHex: String
    public var isPinned: Bool
    public var sortOrder: Int
    public var createdAt: Date
    /// Optional because SwiftData migrations of existing stores need a
    /// nilable default. Existing rows pick up `nil` until the user edits the
    /// app and Peel fetches its icon.
    public var iconData: Data?

    public init(from config: AppConfig) {
        self.id = config.id
        self.displayName = config.displayName
        self.bundleId = config.bundleId
        self.issuerId = config.issuerId
        self.keyId = config.keyId
        self.environmentSupportRaw = config.environmentSupport.rawValue
        self.accentColorHex = config.accentColorHex
        self.isPinned = config.isPinned
        self.sortOrder = config.sortOrder
        self.createdAt = config.createdAt
        self.iconData = config.iconData
    }

    public func toValue() -> AppConfig {
        AppConfig(
            id: id,
            displayName: displayName,
            bundleId: bundleId,
            issuerId: issuerId,
            keyId: keyId,
            environmentSupport: AppEnvironmentSupport(rawValue: environmentSupportRaw) ?? .both,
            accentColorHex: accentColorHex,
            isPinned: isPinned,
            sortOrder: sortOrder,
            createdAt: createdAt,
            iconData: iconData
        )
    }

    public func update(from config: AppConfig) {
        displayName = config.displayName
        bundleId = config.bundleId
        issuerId = config.issuerId
        keyId = config.keyId
        environmentSupportRaw = config.environmentSupport.rawValue
        accentColorHex = config.accentColorHex
        isPinned = config.isPinned
        sortOrder = config.sortOrder
        iconData = config.iconData
    }
}

@Model
public final class HistoryEntry {
    @Attribute(.unique) public var id: UUID
    public var appConfigId: UUID
    public var environmentRaw: String
    public var endpointRaw: String
    public var parameterJSON: String
    public var responseStatus: Int
    public var responseBodyRef: String?
    public var sentAt: Date
    public var durationMs: Int
    public var isFavorite: Bool
    public var note: String

    public init(
        id: UUID = UUID(),
        appConfigId: UUID,
        environment: APIEnvironment,
        endpoint: EndpointID,
        parameterJSON: String,
        responseStatus: Int,
        responseBodyRef: String? = nil,
        sentAt: Date = Date(),
        durationMs: Int,
        isFavorite: Bool = false,
        note: String = ""
    ) {
        self.id = id
        self.appConfigId = appConfigId
        self.environmentRaw = environment.rawValue
        self.endpointRaw = endpoint.rawValue
        self.parameterJSON = parameterJSON
        self.responseStatus = responseStatus
        self.responseBodyRef = responseBodyRef
        self.sentAt = sentAt
        self.durationMs = durationMs
        self.isFavorite = isFavorite
        self.note = note
    }

    public var environment: APIEnvironment { APIEnvironment(rawValue: environmentRaw) ?? .sandbox }
    public var endpoint: EndpointID? { EndpointID(rawValue: endpointRaw) }
}

@Model
public final class AuditRecord {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var appConfigId: UUID?
    public var appDisplayName: String?
    public var environmentRaw: String?
    public var endpointRaw: String
    public var isMutating: Bool
    public var userInitiated: Bool
    public var parameterJSON: String
    public var responseStatus: Int?
    public var durationMs: Int?
    public var errorTitle: String?

    public init(_ entry: AuditEntry) {
        self.id = entry.id
        self.timestamp = entry.timestamp
        self.appConfigId = entry.appConfigId
        self.appDisplayName = entry.appDisplayName
        self.environmentRaw = entry.environment?.rawValue
        self.endpointRaw = entry.endpoint.rawValue
        self.isMutating = entry.isMutating
        self.userInitiated = entry.userInitiated
        let data = try? JSONSerialization.data(withJSONObject: entry.parameters, options: [.sortedKeys])
        self.parameterJSON = data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        self.responseStatus = entry.responseStatus
        self.durationMs = entry.durationMs
        self.errorTitle = entry.errorTitle
    }

    public func toValue() -> AuditEntry {
        let params = (try? JSONSerialization.jsonObject(with: Data(parameterJSON.utf8))) as? [String: String] ?? [:]
        return AuditEntry(
            id: id,
            timestamp: timestamp,
            appConfigId: appConfigId,
            appDisplayName: appDisplayName,
            environment: environmentRaw.flatMap(APIEnvironment.init(rawValue:)),
            endpoint: EndpointID(rawValue: endpointRaw) ?? .getTransactionInfo,
            isMutating: isMutating,
            userInitiated: userInitiated,
            parameters: params,
            responseStatus: responseStatus,
            durationMs: durationMs,
            errorTitle: errorTitle
        )
    }
}
