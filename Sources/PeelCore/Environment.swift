import Foundation

public enum APIEnvironment: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case sandbox
    case production

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sandbox: return "Sandbox"
        case .production: return "Production"
        }
    }

    public var baseURL: URL {
        switch self {
        case .sandbox:
            return URL(string: "https://api.storekit-sandbox.itunes.apple.com")!
        case .production:
            return URL(string: "https://api.storekit.itunes.apple.com")!
        }
    }

    public var isDestructiveSurface: Bool { self == .production }
}

public enum AppEnvironmentSupport: String, Codable, CaseIterable, Sendable {
    case sandboxOnly
    case productionOnly
    case both

    public func includes(_ env: APIEnvironment) -> Bool {
        switch self {
        case .sandboxOnly: return env == .sandbox
        case .productionOnly: return env == .production
        case .both: return true
        }
    }
}
