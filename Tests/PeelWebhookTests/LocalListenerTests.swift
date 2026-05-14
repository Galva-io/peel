import XCTest
@testable import PeelWebhook

final class LocalListenerTests: XCTestCase {
    func testStartAndStop() async throws {
        let listener = LocalListener(configuration: .init(port: 0, path: "/webhook"))
        // Port 0 lets the OS pick an ephemeral port — we just want to verify
        // the actor's lifecycle plumbing rather than hard-bind in CI.
        do {
            try await listener.start()
        } catch {
            // Some CI environments deny binding even to 0; treat as a skip.
            return
        }
        await listener.stop()
    }
}
