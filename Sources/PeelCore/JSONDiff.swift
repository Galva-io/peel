import Foundation

/// Structural JSON diff. Walks two `JSONValue` trees and emits a list of
/// edits the response viewer can render as a unified or side-by-side diff.
public struct JSONDiff: Sendable {
    public enum Change: Equatable, Sendable {
        case added(path: Path, value: JSONValue)
        case removed(path: Path, value: JSONValue)
        case changed(path: Path, from: JSONValue, to: JSONValue)

        public var path: Path {
            switch self {
            case let .added(p, _): return p
            case let .removed(p, _): return p
            case let .changed(p, _, _): return p
            }
        }
    }

    public struct Path: Equatable, Hashable, Sendable {
        public enum Component: Equatable, Hashable, Sendable {
            case key(String)
            case index(Int)
        }
        public let components: [Component]
        public init(_ components: [Component] = []) { self.components = components }
        public func appending(_ c: Component) -> Path { Path(components + [c]) }
        public var pretty: String {
            var s = "$"
            for c in components {
                switch c {
                case let .key(k): s += "." + k
                case let .index(i): s += "[\(i)]"
                }
            }
            return s
        }
    }

    public init() {}

    public func diff(_ a: JSONValue, _ b: JSONValue) -> [Change] {
        var changes: [Change] = []
        walk(a, b, path: Path(), changes: &changes)
        return changes
    }

    private func walk(_ a: JSONValue, _ b: JSONValue, path: Path, changes: inout [Change]) {
        if a == b { return }
        switch (a, b) {
        case let (.object(la), .object(lb)):
            let aDict = Dictionary(uniqueKeysWithValues: la.map { ($0.key, $0.value) })
            let bDict = Dictionary(uniqueKeysWithValues: lb.map { ($0.key, $0.value) })
            // Process A keys first to preserve a stable ordering.
            var seen = Set<String>()
            for pair in la {
                seen.insert(pair.key)
                let next = path.appending(.key(pair.key))
                if let bv = bDict[pair.key] {
                    walk(pair.value, bv, path: next, changes: &changes)
                } else {
                    changes.append(.removed(path: next, value: pair.value))
                }
            }
            for pair in lb where !seen.contains(pair.key) {
                let next = path.appending(.key(pair.key))
                if let av = aDict[pair.key] {
                    walk(av, pair.value, path: next, changes: &changes)
                } else {
                    changes.append(.added(path: next, value: pair.value))
                }
            }
        case let (.array(la), .array(lb)):
            let common = min(la.count, lb.count)
            for i in 0..<common {
                walk(la[i], lb[i], path: path.appending(.index(i)), changes: &changes)
            }
            if la.count > lb.count {
                for i in lb.count..<la.count {
                    changes.append(.removed(path: path.appending(.index(i)), value: la[i]))
                }
            } else if lb.count > la.count {
                for i in la.count..<lb.count {
                    changes.append(.added(path: path.appending(.index(i)), value: lb[i]))
                }
            }
        default:
            changes.append(.changed(path: path, from: a, to: b))
        }
    }

    /// Renders a compact summary for the "Show me what changed" card. Names
    /// well-known App Store Server API fields where we recognize them.
    public func summarize(_ changes: [Change]) -> [String] {
        let semantic = SemanticDiffFormatter()
        return changes.compactMap { semantic.summarize($0) }
    }

    /// Produces a Markdown diff block for sharing in tickets.
    public func renderMarkdown(_ changes: [Change]) -> String {
        guard !changes.isEmpty else { return "_(no differences)_" }
        var out = "| Path | Change |\n| --- | --- |\n"
        for change in changes {
            switch change {
            case let .added(p, v):
                out += "| `\(p.pretty)` | + \(v.encodeCompact()) |\n"
            case let .removed(p, v):
                out += "| `\(p.pretty)` | - \(v.encodeCompact()) |\n"
            case let .changed(p, from, to):
                out += "| `\(p.pretty)` | \(from.encodeCompact()) → \(to.encodeCompact()) |\n"
            }
        }
        return out
    }
}

struct SemanticDiffFormatter {
    func summarize(_ change: JSONDiff.Change) -> String? {
        switch change {
        case let .changed(path, from, to):
            let key = path.components.last
            if case let .key(name) = key {
                switch name {
                case "expiresDate":
                    if let a = epochValue(from), let b = epochValue(to) {
                        let days = (b - a) / 86400
                        if days > 0 { return "Subscription extended by \(Int(days)) days" }
                        if days < 0 { return "Subscription shortened by \(Int(-days)) days" }
                    }
                case "status":
                    if let a = from.stringValue ?? from.numberValue?.literal,
                       let b = to.stringValue ?? to.numberValue?.literal {
                        return "Status \(a) → \(b)"
                    }
                case "autoRenewStatus":
                    if let a = from.numberValue?.intValue, let b = to.numberValue?.intValue {
                        return a == 1 ? "Auto-renew turned off" : "Auto-renew turned on"
                    }
                default: break
                }
            }
            return "\(path.pretty) changed"
        case let .added(path, _):
            return "Added \(path.pretty)"
        case let .removed(path, _):
            return "Removed \(path.pretty)"
        }
    }

    private func epochValue(_ v: JSONValue) -> Double? {
        if let n = v.numberValue?.doubleValue { return n / 1000 }
        return nil
    }
}
