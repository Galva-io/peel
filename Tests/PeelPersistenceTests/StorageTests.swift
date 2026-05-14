import XCTest
@testable import PeelPersistence
import PeelCore

final class StorageTests: XCTestCase {
    func testSaveAndFetchAppConfigs() async throws {
        let storage = try Storage.makeInMemory()
        let config = AppConfig(displayName: "Foo", bundleId: "com.foo", issuerId: UUID().uuidString, keyId: "ABCDEFGHIJ")
        try await storage.saveAppConfig(config)
        let apps = try await storage.allAppConfigs()
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps[0].displayName, "Foo")
    }

    func testHistoryRecordRoundTrip() async throws {
        let storage = try Storage.makeInMemory()
        let appId = UUID()
        _ = try await storage.recordHistory(
            appConfigId: appId,
            environment: .sandbox,
            endpoint: .getTransactionInfo,
            parameters: ["transactionId": "1"],
            responseStatus: 200,
            responseBody: Data(#"{"a":1}"#.utf8),
            durationMs: 42
        )
        let history = try await storage.fetchHistory(limit: 10)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].responseStatus, 200)
        XCTAssertEqual(history[0].appConfigId, appId)
    }

    func testAuditAppend() async throws {
        let storage = try Storage.makeInMemory()
        let entry = AuditEntry(
            appConfigId: UUID(),
            appDisplayName: "App",
            environment: .sandbox,
            endpoint: .getTransactionInfo,
            isMutating: false,
            userInitiated: true,
            parameters: ["transactionId": "1"]
        )
        try await storage.appendAudit(entry)
        let entries = try await storage.fetchAudit(limit: 10)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].appDisplayName, "App")
    }

    func testBlobOverflow() async throws {
        let storage = try Storage.makeInMemory()
        let appId = UUID()
        let big = Data(repeating: 0x41, count: 70_000)
        _ = try await storage.recordHistory(
            appConfigId: appId,
            environment: .sandbox,
            endpoint: .getTransactionInfo,
            parameters: [:],
            responseStatus: 200,
            responseBody: big,
            durationMs: 1
        )
        let history = try await storage.fetchHistory(limit: 1)
        let body = try await storage.loadResponseBody(for: history[0])
        XCTAssertEqual(body.count, 70_000)
    }
}
