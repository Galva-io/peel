import Foundation
import PeelCore

/// Wire-level shape of a request to the App Store Server API. Each endpoint
/// builds one of these from a `RequestParameters` value and the active
/// `APIEnvironment`. The shape is intentionally minimal — `Client` adds the
/// `Authorization` header and `User-Agent` itself, so endpoints stay focused
/// on the API surface.
public struct EndpointSpec: Sendable {
    public enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
    }

    public let id: EndpointID
    public let method: Method
    public let pathTemplate: String
    public let pathParameters: [String: String]
    public let queryItems: [URLQueryItem]
    public let body: Data?

    public init(
        id: EndpointID,
        method: Method,
        pathTemplate: String,
        pathParameters: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) {
        self.id = id
        self.method = method
        self.pathTemplate = pathTemplate
        self.pathParameters = pathParameters
        self.queryItems = queryItems
        self.body = body
    }

    public func resolvedPath() -> String {
        var path = pathTemplate
        for (k, v) in pathParameters {
            let escaped = v.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? v
            path = path.replacingOccurrences(of: "{\(k)}", with: escaped)
        }
        return path
    }

    public func url(in environment: APIEnvironment) -> URL {
        var components = URLComponents(url: environment.baseURL, resolvingAgainstBaseURL: false)!
        components.path = resolvedPath()
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url!
    }
}
