import SwiftUI
import PeelCore

/// Multi-select country picker rendered as wrapping tag chips with a
/// search-as-you-type "Add" button that opens a popover of all ISO 3166
/// regions. The value is stored as a comma-separated string in
/// `RequestParameters` so the request builder and downstream code don't
/// need to know about country tags at all.
struct CountryTagField: View {
    @Binding var codesString: String
    @State private var showingPicker = false

    private var codes: [String] {
        codesString
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        FlowLayout(spacing: 5, lineSpacing: 5) {
            ForEach(codes, id: \.self) { code in
                CountryTagChip(code: code) { remove(code) }
            }
            Button {
                showingPicker = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .imageScale(.small)
                    Text("Add")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 7)
                .frame(height: 20)
                .foregroundStyle(.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
                CountrySearchPopover(selected: codes) { country in
                    add(country.code)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func add(_ code: String) {
        let normalized = code.uppercased()
        guard !codes.contains(normalized) else { return }
        codesString = (codes + [normalized]).joined(separator: ",")
    }

    private func remove(_ code: String) {
        codesString = codes.filter { $0 != code }.joined(separator: ",")
    }
}

struct CountryTagChip: View {
    let code: String
    let onRemove: () -> Void

    private var country: CountryCatalog.Country? {
        CountryCatalog.country(forCode: code)
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(country?.flag ?? "🏳")
                .font(.system(size: 11))
            Text(code)
                .font(.system(size: 11, weight: .medium))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .frame(height: 20)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1))
        )
        .help(country?.name ?? code)
    }
}

/// Popover used by `CountryTagField`: top-anchored search field over a
/// scrollable list of matching countries. Already-selected countries are
/// dimmed and disabled so users can't add duplicates.
struct CountrySearchPopover: View {
    let selected: [String]
    let onPick: (CountryCatalog.Country) -> Void

    @State private var query: String = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [CountryCatalog.Country] {
        CountryCatalog.search(query)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                TextField("Search countries", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.small)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.bar)

            Divider()

            List(filtered, id: \.id) { country in
                Button {
                    onPick(country)
                } label: {
                    HStack(spacing: 8) {
                        Text(country.flag)
                            .font(.system(size: 13))
                        Text(country.name)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(country.code)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(selected.contains(country.code))
                .opacity(selected.contains(country.code) ? 0.4 : 1)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 320, height: 380)
        .onAppear { searchFocused = true }
    }
}
