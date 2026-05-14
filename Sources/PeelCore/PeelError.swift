import Foundation

/// Domain-level error type. Every layer of Peel translates platform-specific
/// errors into one of these so the UI has a single shape to render.
public struct PeelError: Error, Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        case configuration
        case keychain
        case auth
        case network
        case decoding
        case validation
        case webhook
        case persistence
        case sandbox          // app-sandbox / entitlement
        case unknown
    }

    public let kind: Kind
    public let title: String
    public let message: String
    public let remediation: String?
    public let underlyingDescription: String?

    public init(
        kind: Kind,
        title: String,
        message: String,
        remediation: String? = nil,
        underlyingDescription: String? = nil
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.remediation = remediation
        self.underlyingDescription = underlyingDescription
    }

    public var errorDescription: String? { message }
}

extension PeelError {
    public static func configuration(_ message: String, remediation: String? = nil) -> PeelError {
        PeelError(kind: .configuration, title: "Configuration", message: message, remediation: remediation)
    }
    public static func validation(_ message: String) -> PeelError {
        PeelError(kind: .validation, title: "Invalid input", message: message)
    }
    public static func decoding(_ message: String, underlying: Error? = nil) -> PeelError {
        PeelError(kind: .decoding, title: "Decoding failed", message: message,
                  underlyingDescription: underlying.map { String(describing: $0) })
    }
    public static func network(_ message: String, underlying: Error? = nil) -> PeelError {
        PeelError(kind: .network, title: "Network", message: message,
                  underlyingDescription: underlying.map { String(describing: $0) })
    }
    public static func keychain(_ message: String) -> PeelError {
        PeelError(kind: .keychain, title: "Keychain", message: message)
    }
}
