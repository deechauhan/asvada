import Foundation
import Model

public extension PreviewData {
    /// A city to scatter stress places around: a name, and where it is.
    private struct StressCity {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    private static let stressCities = [
        StressCity(name: "London", latitude: 51.51, longitude: -0.12),
        StressCity(name: "Paris", latitude: 48.86, longitude: 2.35),
        StressCity(name: "Lisbon", latitude: 38.72, longitude: -9.14),
        StressCity(name: "Berlin", latitude: 52.52, longitude: 13.40),
        StressCity(name: "Rome", latitude: 41.90, longitude: 12.50),
        StressCity(name: "Istanbul", latitude: 41.01, longitude: 28.98),
        StressCity(name: "Reykjavik", latitude: 64.15, longitude: -21.94),
        StressCity(name: "Marrakech", latitude: 31.63, longitude: -7.99),
        StressCity(name: "Cairo", latitude: 30.04, longitude: 31.24),
        StressCity(name: "Nairobi", latitude: -1.29, longitude: 36.82),
        StressCity(name: "Cape Town", latitude: -33.92, longitude: 18.42),
        StressCity(name: "Dubai", latitude: 25.20, longitude: 55.27),
        StressCity(name: "Mumbai", latitude: 19.08, longitude: 72.88),
        StressCity(name: "Bangkok", latitude: 13.76, longitude: 100.50),
        StressCity(name: "Hanoi", latitude: 21.03, longitude: 105.85),
        StressCity(name: "Singapore", latitude: 1.35, longitude: 103.82),
        StressCity(name: "Seoul", latitude: 37.57, longitude: 126.98),
        StressCity(name: "Tokyo", latitude: 35.68, longitude: 139.69),
        StressCity(name: "Sydney", latitude: -33.87, longitude: 151.21),
        StressCity(name: "Auckland", latitude: -36.85, longitude: 174.76),
        StressCity(name: "Vancouver", latitude: 49.28, longitude: -123.12),
        StressCity(name: "San Francisco", latitude: 37.77, longitude: -122.42),
        StressCity(name: "Mexico City", latitude: 19.43, longitude: -99.13),
        StressCity(name: "New York", latitude: 40.71, longitude: -74.01),
        StressCity(name: "Toronto", latitude: 43.65, longitude: -79.38),
        StressCity(name: "Lima", latitude: -12.05, longitude: -77.04),
        StressCity(name: "Rio de Janeiro", latitude: -22.91, longitude: -43.17),
        StressCity(name: "Buenos Aires", latitude: -34.60, longitude: -58.38),
    ]

    /// Adds `count` places around the world, for measuring the Atlas under load (`-stressPlaces N`,
    /// #53): cafés, restaurants and cities scattered round 28 cities, each with one entry, so
    /// pins pile up the way a real map does and their countries ink. The same count always makes
    /// the same places (a fixed seed), so two runs are comparable.
    static func addStressPlaces(_ count: Int, to repository: Repository) throws {
        let kinds: [CollectionKind] = [.cafes, .restaurants, .cities]
        let collections = try repository.collections(includeHidden: true)
        let targets = kinds.compactMap { kind in collections.first { $0.kind == kind } }
        guard !targets.isEmpty, count > 0 else { return }
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(1 << 53)
        }
        for index in 0 ..< count {
            // Busier cities get more places: the first cities in the list are the busiest.
            let city = stressCities[Int(pow(next(), 1.6) * Double(stressCities.count))]
            let collection = targets[index % targets.count]
            let name = "\(city.name) place \(index + 1)"
            let item = repository.upsertItem(named: name, externalRef: "stress-place:\(index)", in: collection)
            // About 15 km either way, so pins land on top of each other once zoomed out.
            item.latitude = city.latitude + (next() - 0.5) * 0.3
            item.longitude = city.longitude + (next() - 0.5) * 0.3
            repository.addEntry(to: item, date: .now.addingTimeInterval(-Double(index + 1) * 7200))
        }
    }
}
