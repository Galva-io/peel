import Foundation

/// Decodes the nested JWS payloads Apple returns from the App Store Server
/// API. Each response can carry several levels of signed JWTs:
///
///     responseBody                  (top-level JSON)
///       └─ signedTransactionInfo    (JWS string)
///            └─ decoded transaction
///       └─ signedRenewalInfo        (JWS string)
///            └─ decoded renewal
///       └─ signedPayload            (server-notification JWS)
///            └─ responseBodyV2DecodedPayload
///
/// `JWSDecoder` walks the tree, decoding every `signed*` string it finds.
/// Signature verification against Apple's root CA is a planned follow-on; for
/// now the decoder records whether an `x5c` chain was present.
public struct JWSDecoder: Sendable {
    public init() {}

    /// Walks the JSON tree and replaces any string value whose key starts with
    /// `signed` (case-insensitive) with a `DecodedJWS` envelope containing the
    /// parsed payload and a metadata block.
    public func decodeTree(_ raw: Data) throws -> JSONValue {
        let root = try JSONValue(data: raw)
        return decodeValue(root)
    }

    public func decodeTree(_ value: JSONValue) -> JSONValue {
        decodeValue(value)
    }

    private func decodeValue(_ value: JSONValue) -> JSONValue {
        switch value {
        case let .object(pairs):
            var out: [JSONValue.Pair] = []
            out.reserveCapacity(pairs.count)
            for pair in pairs {
                if case let .string(s) = pair.value, looksLikeSignedKey(pair.key), looksLikeJWS(s) {
                    if let decoded = try? decodeOne(jws: s) {
                        let envelope = JSONValue.object([
                            JSONValue.Pair("__peel_jws", .bool(true)),
                            JSONValue.Pair("header", decoded.header),
                            JSONValue.Pair("payload", decodeValue(decoded.payload)),
                            JSONValue.Pair("x5cPresent", .bool(decoded.x5cPresent)),
                            JSONValue.Pair("signatureValid", .null), // future: cert chain verification
                            JSONValue.Pair("raw", .string(s))
                        ])
                        out.append(JSONValue.Pair(pair.key, envelope))
                        continue
                    }
                }
                out.append(JSONValue.Pair(pair.key, decodeValue(pair.value)))
            }
            return .object(out)
        case let .array(items):
            return .array(items.map(decodeValue))
        default:
            return value
        }
    }

    private func looksLikeSignedKey(_ key: String) -> Bool {
        let lower = key.lowercased()
        return lower.hasPrefix("signed")
    }

    private func looksLikeJWS(_ s: String) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 3 && parts.allSatisfy { !$0.isEmpty }
    }

    public struct DecodedJWS: Sendable {
        public let header: JSONValue
        public let payload: JSONValue
        public let x5cPresent: Bool
        public let signature: Data
    }

    public func decodeOne(jws: String) throws -> DecodedJWS {
        let parts = jws.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            throw PeelError.decoding("JWS must have three segments")
        }
        guard let headerData = Base64URL.decode(String(parts[0])),
              let payloadData = Base64URL.decode(String(parts[1])),
              let signature = Base64URL.decode(String(parts[2])) else {
            throw PeelError.decoding("JWS segments are not valid base64url")
        }
        let header = try JSONValue(data: headerData)
        let payload = try JSONValue(data: payloadData)
        let x5cPresent: Bool
        if case let .object(pairs) = header, pairs.contains(where: { $0.key == "x5c" }) {
            x5cPresent = true
        } else {
            x5cPresent = false
        }
        return DecodedJWS(header: header, payload: payload, x5cPresent: x5cPresent, signature: signature)
    }
}
