import XCTest
@testable import PeelCore

final class AppStoreLookupTests: XCTestCase {
    func testExtractsAppIDFromAppsAppleComURL() {
        XCTAssertEqual(AppStoreLookup.extractAppID(from: "https://apps.apple.com/us/app/foo/id1234567890"), "1234567890")
        XCTAssertEqual(AppStoreLookup.extractAppID(from: "https://apps.apple.com/app/id987654321"), "987654321")
    }

    func testExtractsBareID() {
        XCTAssertEqual(AppStoreLookup.extractAppID(from: "id555"), "555")
        XCTAssertEqual(AppStoreLookup.extractAppID(from: "1234567890"), "1234567890")
    }

    func testReturnsNilForNonAppStoreInput() {
        XCTAssertNil(AppStoreLookup.extractAppID(from: "com.example.app"))
        XCTAssertNil(AppStoreLookup.extractAppID(from: ""))
    }

    func testLookupParsesITunesResponse() async throws {
        let json = """
        {"resultCount":1,"results":[{"bundleId":"com.example.app","trackName":"Example","trackId":42,"artworkUrl512":"https://is1-ssl.mzstatic.com/image/512x512.png","trackViewUrl":"https://apps.apple.com/app/id42"}]}
        """
        let stub = StubTransport(payload: Data(json.utf8))
        let lookup = AppStoreLookup(transport: stub, allowlist: ["itunes.apple.com"])
        let metadata = try await lookup.lookup(bundleId: "com.example.app")
        XCTAssertEqual(metadata.bundleId, "com.example.app")
        XCTAssertEqual(metadata.name, "Example")
        XCTAssertEqual(metadata.artworkURL?.absoluteString, "https://is1-ssl.mzstatic.com/image/512x512.png")
    }

    func testLookupSurfacesNotFoundForEmptyResults() async {
        let stub = StubTransport(payload: Data(#"{"resultCount":0,"results":[]}"#.utf8))
        let lookup = AppStoreLookup(transport: stub, allowlist: ["itunes.apple.com"])
        do {
            _ = try await lookup.lookup(bundleId: "com.nonexistent.app")
            XCTFail("expected throw")
        } catch let failure as AppStoreLookup.Failure {
            XCTAssertEqual(failure, .notFound)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testAllowlistBlocksUnknownHosts() async {
        let stub = StubTransport(payload: Data())
        let lookup = AppStoreLookup(transport: stub, allowlist: [])
        do {
            _ = try await lookup.lookup(bundleId: "com.x.y")
            XCTFail("expected throw")
        } catch let failure as AppStoreLookup.Failure {
            if case .network = failure { /* ok */ } else { XCTFail("expected .network, got \(failure)") }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

final class StubTransport: AppStoreLookup.Transport, @unchecked Sendable {
    let payload: Data
    init(payload: Data) { self.payload = payload }
    func get(_ url: URL) async throws -> Data { payload }
}
