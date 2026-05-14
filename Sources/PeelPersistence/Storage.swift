import Foundation
import SwiftData
import PeelCore

/// Thin facade around `ModelContainer` so the rest of the app talks to a
/// stable, value-shaped API instead of SwiftData fetch descriptors.
///
/// Concurrency: the underlying `ModelContext` is bound to the thread that
/// created it. We isolate everything inside the actor; callers `await` the
/// methods and never touch SwiftData types directly.
public actor Storage {
    public enum Failure: Error { case notFound }

    public static let schemaVersion = "1.0.0"

    private let container: ModelContainer
    private let blobsDirectory: URL
    private let blobThreshold: Int

    /// Default storage rooted in `~/Library/Application Support/Peel/`.
    public static func makeDefault() throws -> Storage {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Peel", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let dbURL = support.appendingPathComponent("peel.store")
        let blobs = support.appendingPathComponent("blobs", isDirectory: true)
        try FileManager.default.createDirectory(at: blobs, withIntermediateDirectories: true)
        let config = ModelConfiguration(url: dbURL)
        let container = try ModelContainer(
            for: StoredAppConfig.self, HistoryEntry.self, AuditRecord.self,
            configurations: config
        )
        return Storage(container: container, blobsDirectory: blobs)
    }

    /// In-memory storage for tests.
    public static func makeInMemory() throws -> Storage {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: StoredAppConfig.self, HistoryEntry.self, AuditRecord.self,
            configurations: config
        )
        let blobs = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PeelBlobs-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: blobs, withIntermediateDirectories: true)
        return Storage(container: container, blobsDirectory: blobs)
    }

    public init(container: ModelContainer, blobsDirectory: URL, blobThreshold: Int = 65_536) {
        self.container = container
        self.blobsDirectory = blobsDirectory
        self.blobThreshold = blobThreshold
    }

    // MARK: - App configs

    public func saveAppConfig(_ config: AppConfig) throws {
        let context = ModelContext(container)
        let id = config.id
        let descriptor = FetchDescriptor<StoredAppConfig>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: config)
        } else {
            context.insert(StoredAppConfig(from: config))
        }
        try context.save()
    }

    public func deleteAppConfig(id: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<StoredAppConfig>(predicate: #Predicate { $0.id == id })
        if let row = try context.fetch(descriptor).first {
            context.delete(row)
            try context.save()
        }
    }

    public func allAppConfigs() throws -> [AppConfig] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<StoredAppConfig>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let rows = try context.fetch(descriptor)
        // Pinned apps float to the top, but `Bool` keypath sorting isn't
        // supported on SwiftData's `SortDescriptor`, so stable-sort manually.
        return rows
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                return lhs.sortOrder < rhs.sortOrder
            }
            .map { $0.toValue() }
    }

    public func reorderAppConfigs(ids: [UUID]) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<StoredAppConfig>()
        let rows = try context.fetch(descriptor)
        var byId: [UUID: StoredAppConfig] = [:]
        for row in rows { byId[row.id] = row }
        for (offset, id) in ids.enumerated() {
            byId[id]?.sortOrder = offset
        }
        try context.save()
    }

    // MARK: - History

    public struct HistoryRecord: Sendable, Identifiable, Hashable {
        public let id: UUID
        public let appConfigId: UUID
        public let environment: APIEnvironment
        public let endpoint: EndpointID
        public let parameters: [String: String]
        public let responseStatus: Int
        public let sentAt: Date
        public let durationMs: Int
        public let isFavorite: Bool
        public let note: String
        public let bodyRef: String?
    }

    public func recordHistory(
        appConfigId: UUID,
        environment: APIEnvironment,
        endpoint: EndpointID,
        parameters: [String: String],
        responseStatus: Int,
        responseBody: Data,
        durationMs: Int,
        note: String = ""
    ) throws -> UUID {
        let context = ModelContext(container)
        let id = UUID()
        var bodyRef: String? = nil
        if responseBody.count > blobThreshold {
            let url = blobsDirectory.appendingPathComponent("\(id.uuidString).json")
            try responseBody.write(to: url, options: [.atomic])
            bodyRef = url.lastPathComponent
        } else {
            bodyRef = "inline:" + (String(data: responseBody, encoding: .utf8) ?? "")
        }
        let parameterJSON = (try? JSONSerialization.data(withJSONObject: parameters, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let entry = HistoryEntry(
            id: id,
            appConfigId: appConfigId,
            environment: environment,
            endpoint: endpoint,
            parameterJSON: parameterJSON,
            responseStatus: responseStatus,
            responseBodyRef: bodyRef,
            durationMs: durationMs,
            note: note
        )
        context.insert(entry)
        try context.save()
        return id
    }

    public func loadResponseBody(for record: HistoryRecord) throws -> Data {
        guard let ref = record.bodyRef else { return Data() }
        if ref.hasPrefix("inline:") {
            return Data(String(ref.dropFirst("inline:".count)).utf8)
        }
        let url = blobsDirectory.appendingPathComponent(ref)
        return try Data(contentsOf: url)
    }

    public func fetchHistory(limit: Int = 500) throws -> [HistoryRecord] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.sentAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).map { entry in
            let params = (try? JSONSerialization.jsonObject(with: Data(entry.parameterJSON.utf8))) as? [String: String] ?? [:]
            return HistoryRecord(
                id: entry.id,
                appConfigId: entry.appConfigId,
                environment: entry.environment,
                endpoint: entry.endpoint ?? .getTransactionInfo,
                parameters: params,
                responseStatus: entry.responseStatus,
                sentAt: entry.sentAt,
                durationMs: entry.durationMs,
                isFavorite: entry.isFavorite,
                note: entry.note,
                bodyRef: entry.responseBodyRef
            )
        }
    }

    public func toggleFavorite(historyId: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<HistoryEntry>(predicate: #Predicate { $0.id == historyId })
        guard let entry = try context.fetch(descriptor).first else { return }
        entry.isFavorite.toggle()
        try context.save()
    }

    public func deleteHistory(id: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<HistoryEntry>(predicate: #Predicate { $0.id == id })
        if let entry = try context.fetch(descriptor).first {
            if let ref = entry.responseBodyRef, !ref.hasPrefix("inline:") {
                let url = blobsDirectory.appendingPathComponent(ref)
                try? FileManager.default.removeItem(at: url)
            }
            context.delete(entry)
            try context.save()
        }
    }

    public func purgeHistoryOlderThan(_ cutoff: Date) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { $0.sentAt < cutoff }
        )
        let rows = try context.fetch(descriptor)
        for row in rows {
            if let ref = row.responseBodyRef, !ref.hasPrefix("inline:") {
                let url = blobsDirectory.appendingPathComponent(ref)
                try? FileManager.default.removeItem(at: url)
            }
            context.delete(row)
        }
        try context.save()
    }

    // MARK: - Audit log

    public func appendAudit(_ entry: AuditEntry) throws {
        let context = ModelContext(container)
        context.insert(AuditRecord(entry))
        try context.save()
    }

    public func fetchAudit(limit: Int = 1000) throws -> [AuditEntry] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<AuditRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).map { $0.toValue() }
    }

    public func exportAuditJSONL() throws -> String {
        let entries = try fetchAudit(limit: .max)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try entries.map { entry in
            let data = try encoder.encode(entry)
            return String(data: data, encoding: .utf8) ?? ""
        }.joined(separator: "\n")
    }
}
