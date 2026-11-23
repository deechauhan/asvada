import DesignSystem
import Geo
import SwiftUI

/// "Where have you been?" The ink map on top; continent chips, search and a flag grid below.
/// Every tap stamps (or unstamps) a country with a heavy haptic, and the counter rolls.
struct StampStep: View {
    @Binding var stamped: Set<String>
    let onContinue: () -> Void
    @State private var continent: Continent?
    @State private var query = ""

    private var countries: [Country] {
        let matches = CountryCatalog.shared.search(query)
        guard let continent else { return matches }
        return matches.filter { $0.continent == continent }
    }

    var body: some View {
        OnboardingPage(title: "Where have you been?", onContinue: onContinue) {
            InkWorldMap(visited: stamped, onTap: toggle)
            Text(PassportSpreadCard.title(count: stamped.count, worldTotal: DrawerSummary.worldCountries))
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.brand.color)
                .contentTransition(.numericText())
                .accessibilityIdentifier("stampCounter")
            ContinentChips(selection: $continent)
            TextField("Search countries", text: $query)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .accessibilityIdentifier("stampSearch")
            FlagGrid(countries: countries, stamped: stamped, onTap: toggle)
        }
        .haptic(.stamp, trigger: stamped.count)
    }

    private func toggle(_ code: String) {
        withAnimation(.snappy) {
            stamped = CountryPicker.toggled(stamped, code)
        }
    }
}

/// "All" plus one chip per continent.
private struct ContinentChips: View {
    @Binding var selection: Continent?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.small) {
                chip("All", isOn: selection == nil) { selection = nil }
                ForEach(Continent.allCases.filter { $0 != .antarctica }, id: \.self) { continent in
                    chip(continent.name, isOn: selection == continent) { selection = continent }
                }
            }
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .typeToken(.callout)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
                .foregroundStyle(isOn ? Palette.onBrand.color : Palette.textPrimary.color)
                .background(isOn ? Palette.brand.color : Palette.surface.color, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("continent-\(title)")
    }
}

/// Flags in a grid; stamped ones get a plum ring and seal.
private struct FlagGrid: View {
    let countries: [Country]
    let stamped: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: Spacing.small)], spacing: Spacing.small) {
                ForEach(countries) { country in
                    cell(country, isStamped: stamped.contains(country.code))
                }
            }
        }
    }

    private func cell(_ country: Country, isStamped: Bool) -> some View {
        Button {
            onTap(country.code)
        } label: {
            VStack(spacing: Spacing.xxs) {
                Text(country.flag)
                    .font(.system(size: 34))
                Text(country.name)
                    .typeToken(.caption)
                    .foregroundStyle(Palette.textPrimary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium)
                    .strokeBorder(Palette.brand.color, lineWidth: isStamped ? 2 : 0)
            }
            .overlay(alignment: .topTrailing) {
                if isStamped {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Palette.brand.color)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(country.name)
        .accessibilityAddTraits(isStamped ? .isSelected : [])
        .accessibilityIdentifier("flag-\(country.code)")
    }
}
