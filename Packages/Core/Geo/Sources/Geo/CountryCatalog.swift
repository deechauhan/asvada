import Foundation

/// Every country, bundled and offline: simplified Natural Earth 1:50m admin-0 outlines (public
/// domain) built by `scripts/geo/build_countries.py`.
public struct CountryCatalog: Sendable {
    /// The bundled catalog, loaded once on first use.
    public static let shared: CountryCatalog = {
        do {
            guard let url = Bundle.module.url(forResource: "countries", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try CountryCatalog(data: Data(contentsOf: url))
        } catch {
            // The catalog ships inside the module; failing to read it is a build problem.
            fatalError("The bundled country catalog is missing or corrupt: \(error)")
        }
    }()

    /// All countries, sorted by name.
    public let countries: [Country]
    /// Land with no ISO code (e.g. disputed areas): drawn, never selectable.
    public let unassignedLand: [[GeoPoint]]
    private let byCode: [String: Country]

    public init(data: Data) throws {
        let file = try JSONDecoder().decode(CatalogFile.self, from: data)
        countries = file.countries.map { entry in
            let outlines = entry.rings.map(Self.points)
            return Country(
                code: entry.code,
                code3: entry.code3,
                name: entry.name,
                continent: Continent(rawValue: entry.continent) ?? .oceania,
                outlines: outlines,
                bounds: GeoBounds(outlines),
            )
        }
        unassignedLand = file.land.flatMap { $0.rings.map(Self.points) }
        byCode = Dictionary(countries.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The country with ISO code `code` (alpha-2, any case).
    public func country(code: String) -> Country? {
        byCode[code.uppercased()]
    }

    /// The country whose outline contains `point`, if any (none at sea). When outlines overlap,
    /// the smallest wins: outlines are outer rings only, so Italy's also covers San Marino and
    /// South Africa's covers Lesotho.
    public func country(containing point: GeoPoint) -> Country? {
        countries.filter { $0.contains(point) }.min { $0.bounds.area < $1.bounds.area }
    }

    /// The country a place is in: the one containing it, or else the nearest coast within
    /// `coastKilometres`. The outlines are simplified, so a harbour, a beach or a small island's
    /// capital can sit just off its own coastline; open sea still returns nil.
    public func country(at point: GeoPoint, coastKilometres: Double = 20) -> Country? {
        if let inside = country(containing: point) {
            return inside
        }
        let margin = coastKilometres / 80 // degrees; generous at every latitude we draw
        var best: (country: Country, distance: Double)?
        for country in countries where country.bounds.expanded(by: margin).contains(point) {
            let distance = country.distanceInKilometres(to: point)
            if distance <= coastKilometres, distance < best?.distance ?? .infinity {
                best = (country, distance)
            }
        }
        return best?.country
    }

    /// Countries matching `query` by name (ignoring case and accents) or ISO code, names that start
    /// with the query first. An empty query returns everything.
    public func search(_ query: String) -> [Country] {
        let needle = Self.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return countries }
        let matches = countries.filter { country in
            let name = Self.fold(country.name)
            return name.contains(needle) || country.code.lowercased() == needle || country.code3.lowercased() == needle
        }
        return matches.sorted { lhs, rhs in
            let lhsPrefix = Self.fold(lhs.name).hasPrefix(needle)
            let rhsPrefix = Self.fold(rhs.name).hasPrefix(needle)
            if lhsPrefix != rhsPrefix {
                return lhsPrefix
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// Countries grouped by continent, each group sorted by name.
    public var byContinent: [Continent: [Country]] {
        Dictionary(grouping: countries, by: \.continent)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func points(_ flat: [Double]) -> [GeoPoint] {
        stride(from: 0, to: flat.count - 1, by: 2).map { GeoPoint(longitude: flat[$0], latitude: flat[$0 + 1]) }
    }
}

/// The bundled file's shape.
private struct CatalogFile: Decodable {
    struct Entry: Decodable {
        let code: String
        let code3: String
        let name: String
        let continent: String
        let rings: [[Double]]
    }

    struct Land: Decodable {
        let name: String
        let rings: [[Double]]
    }

    let countries: [Entry]
    let land: [Land]
}
