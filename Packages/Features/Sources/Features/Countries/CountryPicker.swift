import DesignSystem
import Geo
import SwiftUI

/// Search and multi-select countries from the bundled catalog: grouped by continent (with how
/// many of each you've picked), or a flat list of matches while searching. Each row is the flag
/// and the name; picked countries carry a plum seal.
struct CountryPicker: View {
    @Binding var selection: Set<String>
    @State private var query = ""
    private let catalog = CountryCatalog.shared

    private var grouped: [Continent: [Country]] {
        catalog.byContinent
    }

    private var matches: [Country] {
        catalog.search(query)
    }

    var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                ForEach(Continent.allCases.filter { grouped[$0] != nil }, id: \.self) { continent in
                    let countries = grouped[continent] ?? []
                    Section {
                        ForEach(countries) { row(for: $0) }
                    } header: {
                        HStack {
                            Text(continent.name)
                            Spacer()
                            Text("\(Self.picked(in: countries, from: selection)) of \(countries.count)")
                                .monospacedDigit()
                        }
                    }
                }
            } else {
                ForEach(matches) { row(for: $0) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.color)
        .searchable(text: $query, prompt: "Search countries")
        .overlay {
            if matches.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private func row(for country: Country) -> some View {
        let isPicked = selection.contains(country.code)
        return Button {
            selection = Self.toggled(selection, country.code)
        } label: {
            HStack(spacing: Spacing.medium) {
                Text(country.flag)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(country.name)
                    .typeToken(.body)
                    .foregroundStyle(Palette.textPrimary.color)
                Spacer(minLength: 0)
                if isPicked {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Palette.brand.color)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(country.name)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
        .accessibilityIdentifier("country-\(country.code)")
    }

    /// `selection` with `code` added, or removed if it was already there.
    static func toggled(_ selection: Set<String>, _ code: String) -> Set<String> {
        selection.symmetricDifference([code])
    }

    /// How many of `countries` are in `selection`.
    static func picked(in countries: [Country], from selection: Set<String>) -> Int {
        countries.count(where: { selection.contains($0.code) })
    }
}

/// The picker on its own screen under the ink world map, with a running count in the title: for
/// checking the catalog and map (launch argument `-countryPicker`) until onboarding hosts them.
public struct CountryPickerScreen: View {
    @State private var selection: Set<String> = []

    public init() {}

    private var title: String {
        selection.isEmpty ? "Countries" : "\(selection.count) stamped"
    }

    public var body: some View {
        NavigationStack {
            CountryPicker(selection: $selection)
                .safeAreaInset(edge: .top) {
                    // The map floods as you pick; tapping a country on it picks it too.
                    InkWorldMap(visited: selection) { code in
                        selection = CountryPicker.toggled(selection, code)
                    }
                    .padding(.horizontal, Spacing.large)
                    .padding(.vertical, Spacing.small)
                    .background(Palette.background.color)
                }
                .navigationTitle(title)
        }
    }
}

#Preview {
    CountryPickerScreen()
}
