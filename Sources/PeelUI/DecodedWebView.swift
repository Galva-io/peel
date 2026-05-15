import SwiftUI
import WebKit
import PeelCore

/// Hosts a `WKWebView` that renders the decoded JSON tree as HTML. We push
/// new HTML into the view from a background task so the rendering walk
/// doesn't tie up the main actor.
///
/// We use `loadHTMLString` with a `nil` base URL — the page never makes
/// network calls and lives in an isolated origin.
public struct DecodedWebView: NSViewRepresentable {
    public let value: JSONValue
    /// Increments when the parent wants to force a re-render even though
    /// `value` hasn't changed (rare; used for theme changes).
    public let renderToken: Int

    public init(value: JSONValue, renderToken: Int = 0) {
        self.value = value
        self.renderToken = renderToken
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = false
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        // Right-click default: WebKit's reload / inspect items don't make
        // sense in our inert document.
        view.allowsMagnification = false
        view.allowsBackForwardNavigationGestures = false
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        return view
    }

    public func updateNSView(_ view: WKWebView, context: Context) {
        let key = RenderKey(hash: value.hashValue, token: renderToken)
        guard context.coordinator.lastRendered != key else { return }
        context.coordinator.lastRendered = key
        let snapshot = value
        // Capture `view` into an isolated Sendable box rather than the
        // closure capture list — Swift 6 flags mutable variable captures
        // when the closure also crosses an isolation boundary.
        let target = WebViewBox(view: view)
        Task.detached(priority: .userInitiated) {
            let html = JSONHTMLRenderer().render(snapshot)
            await MainActor.run { () -> Void in
                target.view?.loadHTMLString(html, baseURL: nil)
            }
        }
    }

    /// Wraps a weak `WKWebView` reference in a Sendable shell so we can
    /// hand it to a detached Task without tripping Swift 6's strict
    /// concurrency checker.
    private final class WebViewBox: @unchecked Sendable {
        weak var view: WKWebView?
        init(view: WKWebView) { self.view = view }
    }

    /// Marked `@MainActor` so the delegate signature exactly matches the
    /// `WKNavigationDelegate` protocol's main-actor isolation under
    /// Swift 6 — `WKWebView` always dispatches its callbacks on the
    /// main actor.
    @MainActor
    public final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var lastRendered: RenderKey?

        /// Block any link clicks the inert document might surface from
        /// reaching the network. The sandbox would deny them anyway, but
        /// failing earlier avoids a flicker.
        public func webView(_ webView: WKWebView,
                            decidePolicyFor action: WKNavigationAction,
                            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }

    public struct RenderKey: Equatable {
        public let hash: Int
        public let token: Int
    }
}
