import Foundation
import Network
import OSLog
import PeelCore

/// Embedded HTTP server for receiving App Store server notifications during
/// local testing. Bound exclusively to `127.0.0.1` so the device firewall
/// doesn't prompt and so the listener is never reachable from another machine.
///
/// The implementation is intentionally a hand-rolled minimal HTTP parser, not
/// SwiftNIO. We accept any `POST` with a JSON body. Apple's server-to-server
/// notifications are JSON envelopes containing a `signedPayload` JWS.
public actor LocalListener {
    public struct Configuration: Sendable {
        public var port: UInt16
        public var path: String

        public static let defaultConfig = Configuration(port: 9876, path: "/webhook")

        public init(port: UInt16 = 9876, path: String = "/webhook") {
            self.port = port
            self.path = path
        }
    }

    public struct ReceivedNotification: Sendable, Identifiable, Hashable {
        public let id: UUID
        public let receivedAt: Date
        public let method: String
        public let path: String
        public let headers: [String: String]
        public let body: Data
        public let remoteEndpoint: String?
    }

    public enum State: Sendable, Equatable {
        case stopped
        case starting
        case running(port: UInt16)
        case failed(message: String)
    }

    public typealias Handler = @Sendable (ReceivedNotification) -> Void

    private var listener: NWListener?
    private(set) public var state: State = .stopped
    private(set) public var configuration: Configuration
    private var handlers: [UUID: Handler] = [:]
    private let queue = DispatchQueue(label: "io.galva.peel.webhook")

    public init(configuration: Configuration = .defaultConfig) {
        self.configuration = configuration
    }

    public func start() async throws {
        if case .running = state { return }
        state = .starting
        do {
            let params = NWParameters.tcp
            params.acceptLocalOnly = true
            params.allowLocalEndpointReuse = true
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: .ipv4(.loopback),
                port: NWEndpoint.Port(integerLiteral: configuration.port)
            )

            let listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: configuration.port))
            self.listener = listener

            // Capture an unowned reference to self via Task so callbacks can
            // hop back into the actor.
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                Task { await self.accept(connection) }
            }
            listener.stateUpdateHandler = { [weak self] s in
                guard let self else { return }
                Task { await self.applyListenerState(s) }
            }
            listener.start(queue: queue)
        } catch {
            state = .failed(message: error.localizedDescription)
            throw PeelError(
                kind: .webhook,
                title: "Could not start receiver",
                message: "Peel could not bind to localhost:\(configuration.port).",
                remediation: "Pick a different port in Settings → Webhook Receiver.",
                underlyingDescription: error.localizedDescription
            )
        }
    }

    public func stop() async {
        listener?.cancel()
        listener = nil
        state = .stopped
    }

    public func updatePort(_ port: UInt16) async throws {
        await stop()
        configuration = Configuration(port: port, path: configuration.path)
        try await start()
    }

    @discardableResult
    public func addHandler(_ handler: @escaping Handler) -> UUID {
        let id = UUID()
        handlers[id] = handler
        return id
    }

    public func removeHandler(_ id: UUID) {
        handlers[id] = nil
    }

    private func applyListenerState(_ s: NWListener.State) {
        switch s {
        case .ready:
            state = .running(port: configuration.port)
            PeelLog.webhook.info("Listening on 127.0.0.1:\(self.configuration.port, privacy: .public)\(self.configuration.path, privacy: .public)")
        case .failed(let error):
            state = .failed(message: error.localizedDescription)
            PeelLog.webhook.error("Listener failed: \(error.localizedDescription, privacy: .public)")
        case .cancelled:
            state = .stopped
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) async {
        connection.start(queue: queue)
        await read(connection: connection)
    }

    private func read(connection: NWConnection) async {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                PeelLog.webhook.error("Receive error: \(error.localizedDescription, privacy: .public)")
                connection.cancel()
                return
            }
            Task {
                if let data {
                    await self.process(data: data, on: connection)
                }
                if isComplete {
                    connection.cancel()
                }
            }
        }
    }

    private func process(data: Data, on connection: NWConnection) async {
        if let request = HTTPParser.parse(data: data) {
            let endpoint: String? = {
                if case let .hostPort(host, port) = connection.endpoint {
                    return "\(host):\(port)"
                }
                return nil
            }()
            let notification = ReceivedNotification(
                id: UUID(),
                receivedAt: Date(),
                method: request.method,
                path: request.path,
                headers: request.headers,
                body: request.body,
                remoteEndpoint: endpoint
            )
            for handler in handlers.values { handler(notification) }
            let body = "{\"ok\":true}"
            let response = """
            HTTP/1.1 200 OK\r
            Content-Type: application/json\r
            Content-Length: \(body.utf8.count)\r
            Connection: close\r
            \r
            \(body)
            """
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        } else {
            let response = "HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
