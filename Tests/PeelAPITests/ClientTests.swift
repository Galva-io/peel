import XCTest
import CryptoKit
@testable import PeelAPI
@testable import PeelCore

final class ClientTests: XCTestCase {
    func testReadOnlyBlocksMutating() async throws {
        let key = P256.Signing.PrivateKey()
        let store = InMemoryKeyStore()
        let app = AppConfig(displayName: "x", bundleId: "com.x.y", issuerId: UUID().uuidString, keyId: "ABCDEFGHIJ")
        store.store(pem: key.pemRepresentation, account: app.keychainAccount)
        let client = Client(keyFetcher: InMemoryKeyFetcher(store: store), transport: NoNetworkTransport())

        var params = RequestParameters()
        params["transactionId"] = "1"
        params["refundPreference"] = "0"
        let spec = try EndpointBuilder.build(endpoint: .requestRefund, parameters: params)

        do {
            _ = try await client.dispatch(.init(appConfig: app, environment: .sandbox, spec: spec, readOnly: true))
            XCTFail("expected throw")
        } catch let error as PeelError {
            XCTAssertEqual(error.kind, .validation)
        }
    }

    func testAllowlistRejectsUnknownHosts() async throws {
        let key = P256.Signing.PrivateKey()
        let store = InMemoryKeyStore()
        let app = AppConfig(displayName: "x", bundleId: "com.x.y", issuerId: UUID().uuidString, keyId: "ABCDEFGHIJ")
        store.store(pem: key.pemRepresentation, account: app.keychainAccount)
        var settings = Client.Settings()
        settings.allowlist = []
        let client = Client(settings: settings, keyFetcher: InMemoryKeyFetcher(store: store), transport: NoNetworkTransport())
        var params = RequestParameters()
        params["transactionId"] = "1"
        let spec = try EndpointBuilder.build(endpoint: .getTransactionInfo, parameters: params)
        do {
            _ = try await client.dispatch(.init(appConfig: app, environment: .sandbox, spec: spec, readOnly: true))
            XCTFail("expected throw")
        } catch let error as PeelError {
            XCTAssertEqual(error.kind, .sandbox)
        }
    }

    func testSuccessfulRoundTrip() async throws {
        let key = P256.Signing.PrivateKey()
        let store = InMemoryKeyStore()
        let app = AppConfig(displayName: "x", bundleId: "com.x.y", issuerId: UUID().uuidString, keyId: "ABCDEFGHIJ")
        store.store(pem: key.pemRepresentation, account: app.keychainAccount)
        let transport = StubTransport(status: 200, body: Data(#"{"status":1}"#.utf8))
        let client = Client(keyFetcher: InMemoryKeyFetcher(store: store), transport: transport)
        var params = RequestParameters()
        params["transactionId"] = "1"
        let spec = try EndpointBuilder.build(endpoint: .getTransactionInfo, parameters: params)
        let response = try await client.dispatch(.init(appConfig: app, environment: .sandbox, spec: spec, readOnly: true))
        XCTAssertEqual(response.status, 200)
        let recorded = try XCTUnwrap(transport.lastRequest)
        XCTAssertTrue((recorded.value(forHTTPHeaderField: "Authorization") ?? "").hasPrefix("Bearer "))
    }
}

final class StubTransport: Client.Transport, @unchecked Sendable {
    let status: Int
    let body: Data
    var lastRequest: URLRequest?
    init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        return (body, response)
    }
}

struct NoNetworkTransport: Client.Transport {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        XCTFail("transport should not have been called: \(request.url?.absoluteString ?? "?")")
        throw URLError(.cancelled)
    }
}
