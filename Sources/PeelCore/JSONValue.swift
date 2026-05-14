import Foundation

/// Ordered, lossless JSON value tree.
///
/// `Foundation.JSONSerialization` returns `[String: Any]` which loses key order
/// and silently coerces numbers. The response viewer needs both stable key
/// ordering (for diffs) and a faithful echo of the wire format, so we walk the
/// raw bytes ourselves once and keep this tree as our canonical shape.
public indirect enum JSONValue: Equatable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(JSONNumber)
    case string(String)
    case array([JSONValue])
    /// Ordered key-value pairs. Multiple identical keys (technically valid in
    /// JSON although rare) are preserved in source order.
    case object([Pair])

    public struct Pair: Hashable, Sendable {
        public let key: String
        public let value: JSONValue
        public init(_ key: String, _ value: JSONValue) {
            self.key = key
            self.value = value
        }
    }

    public init(data: Data) throws {
        var parser = JSONParser(data: data)
        do {
            self = try parser.parse()
        } catch {
            throw PeelError.decoding("Could not parse JSON: \(error)")
        }
    }

    public init(string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw PeelError.decoding("JSON string is not valid UTF-8")
        }
        try self.init(data: data)
    }

    public func encodePretty(sortKeys: Bool = false) -> String {
        var out = ""
        write(into: &out, indent: 0, pretty: true, sortKeys: sortKeys)
        return out
    }

    public func encodeCompact(sortKeys: Bool = false) -> String {
        var out = ""
        write(into: &out, indent: 0, pretty: false, sortKeys: sortKeys)
        return out
    }

    private func write(into out: inout String, indent: Int, pretty: Bool, sortKeys: Bool) {
        let pad = pretty ? String(repeating: "  ", count: indent) : ""
        let nl = pretty ? "\n" : ""
        let sp = pretty ? " " : ""
        switch self {
        case .null:
            out += "null"
        case let .bool(b):
            out += b ? "true" : "false"
        case let .number(n):
            out += n.literal
        case let .string(s):
            out += JSONValue.escape(s)
        case let .array(items):
            if items.isEmpty {
                out += "[]"
                return
            }
            out += "["
            out += nl
            for (i, item) in items.enumerated() {
                out += pretty ? String(repeating: "  ", count: indent + 1) : ""
                item.write(into: &out, indent: indent + 1, pretty: pretty, sortKeys: sortKeys)
                if i < items.count - 1 { out += "," }
                out += nl
            }
            out += pad
            out += "]"
        case let .object(pairs):
            if pairs.isEmpty {
                out += "{}"
                return
            }
            let ordered = sortKeys ? pairs.sorted { $0.key < $1.key } : pairs
            out += "{"
            out += nl
            for (i, pair) in ordered.enumerated() {
                out += pretty ? String(repeating: "  ", count: indent + 1) : ""
                out += JSONValue.escape(pair.key)
                out += ":"
                out += sp
                pair.value.write(into: &out, indent: indent + 1, pretty: pretty, sortKeys: sortKeys)
                if i < ordered.count - 1 { out += "," }
                out += nl
            }
            out += pad
            out += "}"
        }
    }

    static func escape(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        out += "\""
        return out
    }
}

// MARK: - Convenience accessors

extension JSONValue {
    public var stringValue: String? {
        if case let .string(s) = self { return s }
        return nil
    }
    public var boolValue: Bool? {
        if case let .bool(b) = self { return b }
        return nil
    }
    public var numberValue: JSONNumber? {
        if case let .number(n) = self { return n }
        return nil
    }
    public var arrayValue: [JSONValue]? {
        if case let .array(a) = self { return a }
        return nil
    }
    public var objectPairs: [Pair]? {
        if case let .object(o) = self { return o }
        return nil
    }

    public subscript(key: String) -> JSONValue? {
        guard case let .object(pairs) = self else { return nil }
        return pairs.first(where: { $0.key == key })?.value
    }

    public subscript(index: Int) -> JSONValue? {
        guard case let .array(items) = self, items.indices.contains(index) else { return nil }
        return items[index]
    }
}

public extension JSONValue {
    init(_ pairs: [(String, JSONValue)]) {
        self = .object(pairs.map { Pair($0.0, $0.1) })
    }
}

public extension Array where Element == (String, JSONValue) {
    static func == (lhs: [(String, JSONValue)], rhs: [(String, JSONValue)]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
    }
}

/// Number preserving original literal form (so 1.0 doesn't round-trip to 1).
public struct JSONNumber: Equatable, Hashable, Sendable {
    public let literal: String
    public init(_ literal: String) { self.literal = literal }
    public var doubleValue: Double? { Double(literal) }
    public var intValue: Int? { Int(literal) }
}

// MARK: - Minimal recursive-descent JSON parser

struct JSONParser {
    let bytes: [UInt8]
    var index: Int = 0

    init(data: Data) {
        self.bytes = Array(data)
    }

    enum ParseError: Error, CustomStringConvertible {
        case unexpectedEnd
        case unexpected(Character, Int)
        case invalidNumber(Int)
        case invalidString(Int)
        var description: String {
            switch self {
            case .unexpectedEnd: return "unexpected end of input"
            case let .unexpected(c, i): return "unexpected '\(c)' at byte \(i)"
            case let .invalidNumber(i): return "invalid number at byte \(i)"
            case let .invalidString(i): return "invalid string at byte \(i)"
            }
        }
    }

    mutating func parse() throws -> JSONValue {
        skipWhitespace()
        let value = try parseValue()
        skipWhitespace()
        return value
    }

    mutating func parseValue() throws -> JSONValue {
        skipWhitespace()
        guard index < bytes.count else { throw ParseError.unexpectedEnd }
        let c = bytes[index]
        switch c {
        case UInt8(ascii: "{"): return try parseObject()
        case UInt8(ascii: "["): return try parseArray()
        case UInt8(ascii: "\""): return .string(try parseString())
        case UInt8(ascii: "t"), UInt8(ascii: "f"): return try parseBool()
        case UInt8(ascii: "n"): return try parseNull()
        case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"): return try parseNumber()
        default:
            throw ParseError.unexpected(Character(UnicodeScalar(c)), index)
        }
    }

    mutating func parseObject() throws -> JSONValue {
        index += 1 // {
        var pairs: [JSONValue.Pair] = []
        skipWhitespace()
        if peek(UInt8(ascii: "}")) {
            index += 1
            return .object(pairs)
        }
        while true {
            skipWhitespace()
            let key = try parseString()
            skipWhitespace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else {
                throw ParseError.unexpected(":", index)
            }
            index += 1
            let value = try parseValue()
            pairs.append(.init(key, value))
            skipWhitespace()
            guard index < bytes.count else { throw ParseError.unexpectedEnd }
            if bytes[index] == UInt8(ascii: ",") {
                index += 1
                continue
            }
            if bytes[index] == UInt8(ascii: "}") {
                index += 1
                return .object(pairs)
            }
            throw ParseError.unexpected(Character(UnicodeScalar(bytes[index])), index)
        }
    }

    mutating func parseArray() throws -> JSONValue {
        index += 1
        var items: [JSONValue] = []
        skipWhitespace()
        if peek(UInt8(ascii: "]")) {
            index += 1
            return .array(items)
        }
        while true {
            let value = try parseValue()
            items.append(value)
            skipWhitespace()
            guard index < bytes.count else { throw ParseError.unexpectedEnd }
            if bytes[index] == UInt8(ascii: ",") {
                index += 1
                continue
            }
            if bytes[index] == UInt8(ascii: "]") {
                index += 1
                return .array(items)
            }
            throw ParseError.unexpected(Character(UnicodeScalar(bytes[index])), index)
        }
    }

    mutating func parseString() throws -> String {
        guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else {
            throw ParseError.invalidString(index)
        }
        index += 1
        var scalars: [Unicode.Scalar] = []
        while index < bytes.count {
            let c = bytes[index]
            if c == UInt8(ascii: "\"") {
                index += 1
                return String(String.UnicodeScalarView(scalars))
            }
            if c == UInt8(ascii: "\\") {
                index += 1
                guard index < bytes.count else { throw ParseError.unexpectedEnd }
                let esc = bytes[index]
                index += 1
                switch esc {
                case UInt8(ascii: "\""): scalars.append("\"")
                case UInt8(ascii: "\\"): scalars.append("\\")
                case UInt8(ascii: "/"): scalars.append("/")
                case UInt8(ascii: "b"): scalars.append(Unicode.Scalar(0x08))
                case UInt8(ascii: "f"): scalars.append(Unicode.Scalar(0x0C))
                case UInt8(ascii: "n"): scalars.append("\n")
                case UInt8(ascii: "r"): scalars.append("\r")
                case UInt8(ascii: "t"): scalars.append("\t")
                case UInt8(ascii: "u"):
                    guard index + 4 <= bytes.count else { throw ParseError.unexpectedEnd }
                    let hex = String(bytes: bytes[index..<index+4], encoding: .ascii) ?? ""
                    index += 4
                    guard let code = UInt32(hex, radix: 16) else { throw ParseError.invalidString(index) }
                    if (0xD800...0xDBFF).contains(code), index + 6 <= bytes.count,
                       bytes[index] == UInt8(ascii: "\\"), bytes[index + 1] == UInt8(ascii: "u") {
                        let lowHex = String(bytes: bytes[index+2..<index+6], encoding: .ascii) ?? ""
                        if let low = UInt32(lowHex, radix: 16), (0xDC00...0xDFFF).contains(low) {
                            index += 6
                            let combined = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                            if let scalar = Unicode.Scalar(combined) {
                                scalars.append(scalar)
                                continue
                            }
                        }
                    }
                    if let scalar = Unicode.Scalar(code) {
                        scalars.append(scalar)
                    }
                default:
                    throw ParseError.invalidString(index)
                }
                continue
            }
            if c < 0x20 {
                throw ParseError.invalidString(index)
            }
            // Multi-byte UTF-8
            let byteCount: Int
            if c < 0x80 { byteCount = 1 }
            else if c < 0xC0 { throw ParseError.invalidString(index) }
            else if c < 0xE0 { byteCount = 2 }
            else if c < 0xF0 { byteCount = 3 }
            else { byteCount = 4 }
            guard index + byteCount <= bytes.count else { throw ParseError.unexpectedEnd }
            let chunk = Array(bytes[index..<index+byteCount])
            index += byteCount
            if let s = String(bytes: chunk, encoding: .utf8) {
                scalars.append(contentsOf: s.unicodeScalars)
            } else {
                throw ParseError.invalidString(index)
            }
        }
        throw ParseError.unexpectedEnd
    }

    mutating func parseBool() throws -> JSONValue {
        if index + 4 <= bytes.count, bytes[index..<index+4] == ArraySlice("true".utf8) {
            index += 4
            return .bool(true)
        }
        if index + 5 <= bytes.count, bytes[index..<index+5] == ArraySlice("false".utf8) {
            index += 5
            return .bool(false)
        }
        throw ParseError.unexpected(Character(UnicodeScalar(bytes[index])), index)
    }

    mutating func parseNull() throws -> JSONValue {
        if index + 4 <= bytes.count, bytes[index..<index+4] == ArraySlice("null".utf8) {
            index += 4
            return .null
        }
        throw ParseError.unexpected(Character(UnicodeScalar(bytes[index])), index)
    }

    mutating func parseNumber() throws -> JSONValue {
        let start = index
        if bytes[index] == UInt8(ascii: "-") { index += 1 }
        while index < bytes.count {
            let c = bytes[index]
            if (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(c) || c == UInt8(ascii: ".") ||
                c == UInt8(ascii: "e") || c == UInt8(ascii: "E") || c == UInt8(ascii: "+") || c == UInt8(ascii: "-") {
                index += 1
            } else { break }
        }
        guard let literal = String(bytes: bytes[start..<index], encoding: .ascii), !literal.isEmpty else {
            throw ParseError.invalidNumber(start)
        }
        return .number(JSONNumber(literal))
    }

    mutating func skipWhitespace() {
        while index < bytes.count {
            let c = bytes[index]
            if c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D {
                index += 1
            } else { break }
        }
    }

    func peek(_ b: UInt8) -> Bool { index < bytes.count && bytes[index] == b }
}
