import Foundation

/// Local, append-only audit log. Every API call Peel makes generates one
/// entry. Stored via `PeelPersistence` in SwiftData, but `AuditEntry` lives in
/// `PeelCore` so other modules can construct entries without depending on
/// SwiftData.
public struct AuditEntry: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var timestamp: Date
    public var appConfigId: UUID?
    public var appDisplayName: String?
    public var environment: APIEnvironment?
    public var endpoint: EndpointID
    public var isMutating: Bool
    public var userInitiated: Bool
    public var parameters: [String: String]
    public var responseStatus: Int?
    public var durationMs: Int?
    public var errorTitle: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        appConfigId: UUID?,
        appDisplayName: String?,
        environment: APIEnvironment?,
        endpoint: EndpointID,
        isMutating: Bool,
        userInitiated: Bool,
        parameters: [String: String],
        responseStatus: Int? = nil,
        durationMs: Int? = nil,
        errorTitle: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appConfigId = appConfigId
        self.appDisplayName = appDisplayName
        self.environment = environment
        self.endpoint = endpoint
        self.isMutating = isMutating
        self.userInitiated = userInitiated
        self.parameters = parameters
        self.responseStatus = responseStatus
        self.durationMs = durationMs
        self.errorTitle = errorTitle
    }
}

public enum AuditParameterRedactor {
    /// Strips any value whose key looks sensitive. Audit log entries are
    /// never transmitted, but they ARE exportable, so we redact at write time.
    public static func sanitize(_ params: [String: Any]) -> [String: String] {
        let sensitive: Set<String> = [
            "appAccountToken", "email", "customerEmail", "customData",
            "deviceVerification", "deviceVerificationNonce"
        ]
        var out: [String: String] = [:]
        for (key, value) in params {
            if sensitive.contains(key) {
                out[key] = "<redacted>"
            } else if let v = value as? String {
                out[key] = v
            } else {
                out[key] = String(describing: value)
            }
        }
        return out
    }
}
