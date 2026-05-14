import Foundation

/// Canonical list of ISO 3166-1 alpha-2 country codes plus localized
/// names, used by the storefront-codes tag field. We pull from
/// `Locale.Region.isoRegions` so the catalog tracks Foundation rather
/// than living as a hard-coded list that goes stale.
///
/// Apple's App Store supports a subset (~175) of the ~250 ISO regions,
/// but we expose the full list to the picker. Codes Apple doesn't accept
/// will be rejected at the API edge with a clear error — we don't
/// pre-filter because the storefront map shifts over time.
public enum CountryCatalog {
    public struct Country: Sendable, Hashable, Identifiable {
        public let code: String   // 2-letter alpha-2, e.g. "US"
        public let name: String   // localized display name, e.g. "United States"
        public var id: String { code }

        /// Unicode regional-indicator emoji for the code (e.g. 🇺🇸). Built
        /// by offsetting each ASCII letter into the Regional Indicator
        /// Symbol block at U+1F1E6.
        public var flag: String {
            let base: UInt32 = 0x1F1E6
            var out = ""
            for scalar in code.uppercased().unicodeScalars {
                guard scalar.value >= UInt32(UnicodeScalar("A").value),
                      scalar.value <= UInt32(UnicodeScalar("Z").value) else { continue }
                let offset = scalar.value - UInt32(UnicodeScalar("A").value)
                if let flagScalar = Unicode.Scalar(base + offset) {
                    out.unicodeScalars.append(flagScalar)
                }
            }
            return out
        }
    }

    public static let all: [Country] = {
        // `Locale.Region.isoRegions` returns alpha-2 and alpha-3 codes
        // mixed together; we filter to alpha-2 because that's what the
        // App Store Server API speaks.
        let display = Locale.current
        return Locale.Region.isoRegions
            .filter { $0.identifier.count == 2 && $0.identifier.uppercased() == $0.identifier }
            .compactMap { region -> Country? in
                let code = region.identifier
                let name = display.localizedString(forRegionCode: code) ?? code
                return Country(code: code, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    public static func search(_ query: String) -> [Country] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return all }
        return all.filter { country in
            country.name.lowercased().contains(needle) ||
            country.code.lowercased().hasPrefix(needle)
        }
    }

    public static func country(forCode code: String) -> Country? {
        let upper = code.uppercased()
        return all.first(where: { $0.code == upper })
    }
}
