import Foundation

/// Apple-defined enum codes that travel as integers on the wire but show
/// up to users as human labels. Centralised here so the request form and
/// the request builder don't disagree on the lookup table.
public enum AppleEnumValues {
    /// `RefundPreference` per the App Store Server API. Values 0–3, with
    /// 0 meaning "let Apple decide" and 1/2/3 hinting at developer
    /// preference for the dispute outcome.
    public static let refundPreference: [ParameterField.CodedOption] = [
        .init(label: "Undeclared", value: "0"),
        .init(label: "Refund Preferred", value: "1"),
        .init(label: "Refund Not Preferred", value: "2"),
        .init(label: "No Preference", value: "3")
    ]

    /// `ExtendReasonCode` per the App Store Server API. The set is small —
    /// 0 is "we'd rather not say," 1–3 cover the actual reasons.
    public static let extendReason: [ParameterField.CodedOption] = [
        .init(label: "Undeclared", value: "0"),
        .init(label: "Customer Satisfaction", value: "1"),
        .init(label: "Other", value: "2"),
        .init(label: "Service Issue or Outage", value: "3")
    ]
}
