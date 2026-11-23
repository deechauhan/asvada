import Foundation

/// An airline in the bundled catalog.
public struct Airline: Sendable, Hashable, Identifiable, Decodable {
    public let name: String
    /// Two-character IATA designator, e.g. "BA" (what boarding passes print).
    public let iata: String
    /// Three-letter ICAO designator, e.g. "BAW", when known.
    public let icao: String?
    /// ISO 3166-1 alpha-2 code of the airline's country, when known.
    public let country: String?

    public var id: String {
        "\(iata)-\(icao ?? "")-\(name)"
    }

    /// Cargo and similar operations share codes with the passenger airline; they rank below it.
    var isPassengerAirline: Bool {
        !name.localizedCaseInsensitiveContains("cargo")
    }
}

/// Every active airline with an IATA code, bundled and offline: from OpenFlights (ODbL 1.0), built
/// by `scripts/data/build_airlines.py`. See `Packages/Core/Sources/OPENFLIGHTS.md`.
public struct AirlineCatalog: Sendable {
    /// The bundled catalog, loaded once on first use.
    public static let shared: AirlineCatalog = {
        do {
            guard let url = Bundle.module.url(forResource: "airlines", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try AirlineCatalog(data: Data(contentsOf: url))
        } catch {
            // The catalog ships inside the module; failing to read it is a build problem.
            fatalError("The bundled airline catalog is missing or corrupt: \(error)")
        }
    }()

    /// All airlines, sorted by name.
    public let airlines: [Airline]

    public init(data: Data) throws {
        airlines = try JSONDecoder().decode(CatalogFile.self, from: data).airlines
    }

    /// The airline flying as `iata` (any case). Several can share a code (an airline and its cargo
    /// arm, or a code reused after an airline closed): the passenger airline with the shortest name
    /// wins.
    public func airline(iata: String) -> Airline? {
        let code = iata.uppercased()
        return airlines
            .filter { $0.iata == code }
            .min { lhs, rhs in
                if lhs.isPassengerAirline != rhs.isPassengerAirline {
                    return lhs.isPassengerAirline
                }
                return lhs.name.count < rhs.name.count
            }
    }

    /// Airlines matching `query` by name (ignoring case and accents), IATA or ICAO code. Exact code
    /// matches come first, then names that start with the query, then the rest. Empty returns all.
    public func search(_ query: String) -> [Airline] {
        let needle = Self.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return airlines }
        let upper = needle.uppercased()
        func rank(_ airline: Airline) -> Int? {
            if airline.iata == upper || airline.icao == upper {
                return 0
            }
            let name = Self.fold(airline.name)
            if name.hasPrefix(needle) {
                return 1
            }
            return name.contains(needle) ? 2 : nil
        }
        return airlines
            .compactMap { airline in rank(airline).map { (airline, $0) } }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 < rhs.1
                }
                if lhs.0.isPassengerAirline != rhs.0.isPassengerAirline {
                    return lhs.0.isPassengerAirline
                }
                return lhs.0.name.localizedStandardCompare(rhs.0.name) == .orderedAscending
            }
            .map(\.0)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

private struct CatalogFile: Decodable {
    let airlines: [Airline]
}
