import Foundation
import SwiftUI
import Observation
import PeelCore
import PeelAPI
import PeelPersistence
import PeelWebhook

/// Top-level observable state. One instance per process, injected into every
/// window via `@Environment`. Sub-stores own their own scopes so this stays
/// small and the dependency graph is easy to read.
@MainActor
@Observable
public final class PeelAppStore {
    public var apps: [AppConfig] = []
    public var activeAppId: UUID?
    public var environment: APIEnvironment = .sandbox
    public var isReadOnly: Bool = true
    public var auditTrail: [AuditEntry] = []
    public var history: [Storage.HistoryRecord] = []
    public var lastAction: Date?
    public var listenerState: LocalListener.State = .stopped
    public var receivedNotifications: [LocalListener.ReceivedNotification] = []

    public let storage: Storage
    public let keychain: KeychainStore
    public let client: PeelAPI.Client
    public let webhookListener: LocalListener

    public init(
        storage: Storage,
        keychain: KeychainStore = KeychainStore(),
        client: PeelAPI.Client? = nil,
        listener: LocalListener = LocalListener()
    ) {
        self.storage = storage
        self.keychain = keychain
        self.client = client ?? PeelAPI.Client(keyFetcher: KeychainKeyFetcher(store: keychain))
        self.webhookListener = listener
    }

    public func bootstrap() async {
        await reloadApps()
        await reloadHistory()
        await reloadAudit()
        let listener = webhookListener
        _ = await listener.addHandler { [weak self] notification in
            Task { @MainActor in
                self?.receivedNotifications.insert(notification, at: 0)
            }
        }
    }

    public func reloadApps() async {
        do {
            apps = try await storage.allAppConfigs()
            if activeAppId == nil { activeAppId = apps.first?.id }
        } catch {
            PeelLog.persistence.error("Reload apps failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func reloadHistory() async {
        do {
            history = try await storage.fetchHistory(limit: 1000)
        } catch {
            PeelLog.persistence.error("Reload history failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func reloadAudit() async {
        do {
            auditTrail = try await storage.fetchAudit(limit: 1000)
        } catch {
            PeelLog.persistence.error("Reload audit failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public var activeApp: AppConfig? {
        guard let id = activeAppId else { return nil }
        return apps.first(where: { $0.id == id })
    }

    public func addApp(_ config: AppConfig, pem: String) async throws {
        try keychain.store(pem: pem, account: config.keychainAccount)
        try await storage.saveAppConfig(config)
        await reloadApps()
        if activeAppId == nil { activeAppId = config.id }
    }

    public func updateApp(_ config: AppConfig) async throws {
        try await storage.saveAppConfig(config)
        await reloadApps()
    }

    public func deleteApp(_ id: UUID) async throws {
        try? keychain.delete(account: AppConfig(id: id, displayName: "", bundleId: "", issuerId: "", keyId: "").keychainAccount)
        try await storage.deleteAppConfig(id: id)
        await client.evictCachedJWT(for: id)
        await reloadApps()
        if activeAppId == id { activeAppId = apps.first?.id }
    }

    public struct DispatchResult: Sendable {
        public let response: PeelAPI.Client.APIResponse
        public let decoded: JSONValue
    }

    public func send(endpoint: EndpointID, parameters: RequestParameters) async throws -> DispatchResult {
        guard let app = activeApp else {
            throw PeelError.configuration("Add an App Store Connect app context first.",
                                          remediation: "Drag your .p8 key onto Peel to begin.")
        }
        guard app.environmentSupport.includes(environment) else {
            throw PeelError.validation("\(app.displayName) is not configured for \(environment.displayName).")
        }
        let spec = try EndpointBuilder.build(endpoint: endpoint, parameters: parameters)
        let response = try await client.dispatch(.init(
            appConfig: app,
            environment: environment,
            spec: spec,
            readOnly: isReadOnly
        ))
        lastAction = Date()
        let decoded: JSONValue = {
            guard let parsed = try? JSONValue(data: response.body) else { return .object([]) }
            return JWSDecoder().decodeTree(parsed)
        }()
        _ = try await storage.recordHistory(
            appConfigId: app.id,
            environment: environment,
            endpoint: endpoint,
            parameters: parameters.values,
            responseStatus: response.status,
            responseBody: response.body,
            durationMs: response.durationMs
        )
        let audit = AuditEntry(
            appConfigId: app.id,
            appDisplayName: app.displayName,
            environment: environment,
            endpoint: endpoint,
            isMutating: endpoint.isMutating,
            userInitiated: true,
            parameters: AuditParameterRedactor.sanitize(parameters.values),
            responseStatus: response.status,
            durationMs: response.durationMs,
            errorTitle: response.diagnosis?.title
        )
        try await storage.appendAudit(audit)
        await reloadHistory()
        await reloadAudit()
        return DispatchResult(response: response, decoded: decoded)
    }

    public func startWebhookListener() async {
        do {
            try await webhookListener.start()
            listenerState = await webhookListener.state
        } catch {
            listenerState = .failed(message: error.localizedDescription)
        }
    }

    public func stopWebhookListener() async {
        await webhookListener.stop()
        listenerState = await webhookListener.state
    }
}

public extension EnvironmentValues {
    @Entry var peelAppStore: PeelAppStore? = nil
}
