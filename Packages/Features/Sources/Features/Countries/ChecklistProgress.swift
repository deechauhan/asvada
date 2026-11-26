import Foundation
import Geo

/// How much of the world is stamped: "23 · 12%" against the 195 countries, and each continent
/// against the catalogue's places there (territories included, so every stamp counts somewhere).
struct ChecklistProgress: Equatable {
    /// One continent's share, for its MacronBar.
    struct Part: Equatable, Identifiable {
        let continent: Continent
        let stamped: Int
        let total: Int

        var id: Continent {
            continent
        }

        var fraction: Double {
            total > 0 ? Double(stamped) / Double(total) : 0
        }

        /// "Europe, 14 of 50".
        var spoken: String {
            "\(continent.name), \(stamped) of \(total)"
        }
    }

    let stamped: Int
    let total: Int
    let continents: [Part]

    init(stamped codes: Set<String>, catalog: CountryCatalog = .shared, worldTotal: Int = DrawerSummary.worldCountries) {
        let known = codes.compactMap { catalog.country(code: $0) }
        stamped = known.count
        total = worldTotal
        let byContinent = catalog.byContinent
        continents = Continent.allCases.compactMap { continent in
            guard let places = byContinent[continent], !places.isEmpty else { return nil }
            return Part(continent: continent, stamped: known.filter { $0.continent == continent }.count, total: places.count)
        }
    }

    /// Never rounds a real visit down to 0%, as the drawer's own summary doesn't.
    var percent: Int {
        guard stamped > 0, total > 0 else { return 0 }
        return max(1, Int((Double(stamped) / Double(total) * 100).rounded()))
    }

    var fraction: Double {
        total > 0 ? min(Double(stamped) / Double(total), 1) : 0
    }

    /// "23 · 12%", or the ghost line before the first stamp.
    var headline: String {
        stamped == 0 ? "Not one stamp yet" : "\(stamped) · \(percent)%"
    }

    /// "23 of 195 countries, 12 percent".
    var spoken: String {
        stamped == 0 ? "No countries stamped yet" : "\(stamped) of \(total) countries, \(percent) percent"
    }
}
