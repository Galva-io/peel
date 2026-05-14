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
    public var environment: APIEnvironment = .sandbox
    public var isReadOnly: Bool = true
    public var auditTrail: [AuditEntry] = []
    public var history: [Storage.HistoryRecord] = []
    public var lastAction: Date?
    public var listenerState: LocalListener.State = .stopped
    public var receivedNotifications: [LocalListener.ReceivedNotification] = []

    /// Sidebar selection is the canonical (app, endpoint) tuple. The active
    /// app and active endpoint are derived from it; every other view binds
    /// against the derived values.
    public var sidebarSelection: SidebarSelection?

    /// Which app rows are expanded in the sidebar. Persisted via UserDefaults
    /// so the sidebar reopens in the same shape.
    public var expandedAppIds: Set<UUID> = []

    /// Parameter cache per (app, endpoint). When you switch endpoints in the
    /// sidebar, the previously typed inputs are restored.
    public var requestParameters: [SidebarSelection: RequestParameters] = [:]

    /// Latest dispatch result and error per selection. Same restoration
    /// behaviour as `requestParameters`.
    public var lastResults: [SidebarSelection: DispatchResult] = [:]
    public var lastErrors: [SidebarSelection: PeelError] = [:]

    public let storage: Storage
    public let keychain: KeychainStore
    public let client: PeelAPI.Client
    public let webhookListener: LocalListener
    public let appStoreLookup: AppStoreLookup

    public init(
        storage: Storage,
        keychain: KeychainStore = KeychainStore(),
        client: PeelAPI.Client? = nil,
        listener: LocalListener = LocalListener(),
        appStoreLookup: AppStoreLookup = AppStoreLookup()
    ) {
        self.storage = storage
        self.keychain = keychain
        self.client = client ?? PeelAPI.Client(keyFetcher: KeychainKeyFetcher(store: keychain))
        self.webhookListener = listener
        self.appStoreLookup = appStoreLookup
    }

    public func bootstrap() async {
        await reloadApps()
        await reloadHistory()
        await reloadAudit()
        restoreExpansionState()
        if sidebarSelection == nil, let first = apps.first {
            sidebarSelection = SidebarSelection(appId: first.id, endpoint: .getAllSubscriptionStatuses)
            expandedAppIds.insert(first.id)
        }
        let listener = webhookListener
        _ = await listener.addHandler { [weak self] notification in
            Task { @MainActor in
                self?.receivedNotifications.insert(notification, at: 0)
            }
        }
    }

    public var activeAppId: UUID? { sidebarSelection?.appId }
    public var activeApp: AppConfig? {
        guard let id = activeAppId else { return nil }
        return apps.first(where: { $0.id == id })
    }
    public var activeEndpoint: EndpointID? { sidebarSelection?.endpoint }

    public func select(appId: UUID, endpoint: EndpointID) {
        let selection = SidebarSelection(appId: appId, endpoint: endpoint)
        sidebarSelection = selection
        expandedAppIds.insert(appId)
        persistExpansionState()
    }

    public func toggleExpansion(for appId: UUID) {
        if expandedAppIds.contains(appId) {
            expandedAppIds.remove(appId)
        } else {
            expandedAppIds.insert(appId)
        }
        persistExpansionState()
    }

    private func restoreExpansionState() {
        let ids = (UserDefaults.standard.array(forKey: "io.galva.peel.expandedAppIds") as? [String]) ?? []
        expandedAppIds = Set(ids.compactMap(UUID.init(uuidString:)))
    }

    private func persistExpansionState() {
        UserDefaults.standard.set(expandedAppIds.map(\.uuidString),
                                  forKey: "io.galva.peel.expandedAppIds")
    }

    public func reloadApps() async {
        do {
            apps = try await storage.allAppConfigs()
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

    // MARK: - App lifecycle

    public func addApp(_ config: AppConfig, pem: String) async throws {
        try keychain.store(pem: pem, account: config.keychainAccount)
        try await storage.saveAppConfig(config)
        await reloadApps()
        if sidebarSelection == nil {
            sidebarSelection = SidebarSelection(appId: config.id, endpoint: .getAllSubscriptionStatuses)
        }
        expandedAppIds.insert(config.id)
        persistExpansionState()
        // Fetch icon in the background; failure is silent.
        if config.iconData == nil {
            Task { await self.refreshIcon(for: config.id) }
        }
    }

    public func updateApp(_ config: AppConfig) async throws {
        try await storage.saveAppConfig(config)
        await reloadApps()
    }

    public func deleteApp(_ id: UUID) async throws {
        try? keychain.delete(account: AppConfig(id: id, displayName: "", bundleId: "", issuerId: "", keyId: "").keychainAccount)
        try await storage.deleteAppConfig(id: id)
        await client.evictCachedJWT(for: id)
        expandedAppIds.remove(id)
        if activeAppId == id {
            sidebarSelection = apps.first(where: { $0.id != id }).map {
                SidebarSelection(appId: $0.id, endpoint: .getAllSubscriptionStatuses)
            }
        }
        persistExpansionState()
        await reloadApps()
    }

    /// Drops a demo app into the sidebar so first-launch users can explore
    /// the workbench without real credentials. If the demo already exists
    /// we just focus it instead of inserting a duplicate.
    public func addExampleApp() async throws {
        if let existing = apps.first(where: { $0.bundleId == ExampleAppFactory.bundleId }) {
            select(appId: existing.id, endpoint: .getAllSubscriptionStatuses)
            return
        }
        let (config, pem) = ExampleAppFactory.make()
        try await addApp(config, pem: pem)
    }

    public func refreshIcon(for appId: UUID) async {
        guard let app = apps.first(where: { $0.id == appId }) else { return }
        do {
            let metadata = try await appStoreLookup.lookup(bundleId: app.bundleId)
            guard let artworkURL = metadata.artworkURL else { return }
            let data = try await appStoreLookup.downloadArtwork(artworkURL)
            var updated = app
            updated.iconData = data
            try await storage.saveAppConfig(updated)
            await reloadApps()
        } catch {
            PeelLog.api.info("Icon lookup skipped for \(app.bundleId, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Dispatch

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

        // getNotificationHistory has its own paginated path so users can ask
        // for "100 notifications" and we'll follow Apple's paginationToken
        // chain transparently.
        if endpoint == .getNotificationHistory, let limit = Int(parameters["itemLimit"] ?? ""), limit > 0 {
            return try await sendPaginated(
                endpoint: endpoint,
                parameters: parameters,
                limit: limit,
                app: app
            )
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
        try await recordDispatch(
            app: app,
            endpoint: endpoint,
            parameters: parameters,
            response: response
        )
        return DispatchResult(response: response, decoded: decoded)
    }

    /// Walks Apple's `paginationToken` chain for `getNotificationHistory`
    /// until we have `limit` items or the server says `hasMore = false`.
    /// Returns a single synthesized result whose body merges every batch.
    private func sendPaginated(
        endpoint: EndpointID,
        parameters: RequestParameters,
        limit: Int,
        app: AppConfig
    ) async throws -> DispatchResult {
        var working = parameters
        working["paginationToken"] = nil
        // itemLimit is Peel-only; strip it so it doesn't slip into anything
        // the builder might serialize.
        working.values.removeValue(forKey: "itemLimit")

        var collected: [JSONValue] = []
        var lastResponse: PeelAPI.Client.APIResponse?
        var totalDurationMs = 0
        var batches = 0
        var hitError: PeelAPI.Client.APIResponse?

        while collected.count < limit {
            let spec = try EndpointBuilder.build(endpoint: endpoint, parameters: working)
            let response = try await client.dispatch(.init(
                appConfig: app,
                environment: environment,
                spec: spec,
                readOnly: isReadOnly
            ))
            batches += 1
            totalDurationMs += response.durationMs
            lastResponse = response

            // On a non-2xx, bail with what we have and surface the response.
            guard response.isSuccess, let parsed = try? JSONValue(data: response.body) else {
                hitError = response
                break
            }

            if let items = parsed["notificationHistory"]?.arrayValue {
                for item in items {
                    collected.append(item)
                    if collected.count >= limit { break }
                }
            }
            if collected.count >= limit { break }

            // Apple signals end-of-stream via hasMore=false. If absent, stop.
            guard let hasMore = parsed["hasMore"]?.boolValue, hasMore,
                  let nextToken = parsed["paginationToken"]?.stringValue, !nextToken.isEmpty else {
                break
            }
            working["paginationToken"] = nextToken
        }

        lastAction = Date()

        // Build a synthesized response body that looks like a normal Apple
        // response — same shape, but `_peelBatches` tells the user we made
        // multiple calls under the hood.
        let merged: JSONValue = .object([
            JSONValue.Pair("notificationHistory", .array(Array(collected.prefix(limit)))),
            JSONValue.Pair("hasMore", .bool(false)),
            JSONValue.Pair("_peelBatches", .number(JSONNumber("\(batches)"))),
            JSONValue.Pair("_peelTotalDurationMs", .number(JSONNumber("\(totalDurationMs)")))
        ])
        let mergedData = Data(merged.encodeCompact().utf8)
        let decoded = JWSDecoder().decodeTree(merged)

        // Use the final batch's response shape (URL, headers, status) but
        // swap the body so the rest of the app sees the merged view.
        let representative = lastResponse ?? hitError ?? PeelAPI.Client.APIResponse(
            request: URLRequest(url: environment.baseURL),
            status: 0, body: Data(), headers: [:], durationMs: 0, jwt: ""
        )
        let synthesizedResponse = PeelAPI.Client.APIResponse(
            request: representative.request,
            status: hitError?.status ?? 200,
            body: mergedData,
            headers: representative.headers,
            durationMs: totalDurationMs,
            jwt: representative.jwt,
            diagnosis: hitError?.diagnosis
        )

        try await recordDispatch(
            app: app,
            endpoint: endpoint,
            parameters: parameters, // record the user's original params, not the internal `working`
            response: synthesizedResponse
        )

        return DispatchResult(response: synthesizedResponse, decoded: decoded)
    }

    private func recordDispatch(
        app: AppConfig,
        endpoint: EndpointID,
        parameters: RequestParameters,
        response: PeelAPI.Client.APIResponse
    ) async throws {
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
    }

    /// Up to 20 unique transaction IDs the user has entered across every
    /// endpoint. Powers the autocomplete dropdown on transaction-ID fields.
    public var recentTransactionIds: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for record in history {
            for key in ["transactionId", "originalTransactionId"] {
                guard let value = record.parameters[key], !value.isEmpty, !seen.contains(value) else { continue }
                seen.insert(value)
                ordered.append(value)
                if ordered.count >= 20 { return ordered }
            }
        }
        return ordered
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

/// Sidebar selection identifies the (app, endpoint) tuple currently shown in
/// the detail panel. `Hashable` for use as a dictionary key (parameter cache).
public struct SidebarSelection: Hashable, Sendable, Codable {
    public let appId: UUID
    public let endpoint: EndpointID
    public init(appId: UUID, endpoint: EndpointID) {
        self.appId = appId
        self.endpoint = endpoint
    }
}

public extension EnvironmentValues {
    @Entry var peelAppStore: PeelAppStore? = nil
}
