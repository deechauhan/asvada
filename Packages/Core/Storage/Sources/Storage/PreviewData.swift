import Foundation
import Model
import Ranking
import SwiftData

/// An in-memory store filled with sample data, for SwiftUI previews and tests.
@MainActor
public enum PreviewData {
    /// A fresh in-memory container with sample collections, items and entries.
    public static func makeContainer() throws -> ModelContainer {
        let container = try ArtifactsStore.makeContainer(.inMemory)
        try populate(Repository(context: container.mainContext))
        return container
    }

    /// For `#Preview { … .modelContainer(PreviewData.container) }`.
    public static var container: ModelContainer {
        do {
            return try makeContainer()
        } catch {
            fatalError("Could not build the preview store: \(error)")
        }
    }

    static func populate(_ repository: Repository) throws {
        let day: TimeInterval = 86400
        let cafes = ExperienceCollection(
            name: "Cafés",
            icon: "cup.and.saucer.fill",
            kind: .cafes,
            ratingMode: .ranked,
            itemSource: .mapkit,
            sortIndex: 0,
        )
        let countries = ExperienceCollection(
            name: "Countries",
            icon: "globe.europe.africa.fill",
            kind: .countries,
            ratingMode: .checklist,
            defaultView: .progress,
            itemSource: .countryCatalog,
            sortIndex: 1,
        )
        let films = ExperienceCollection(
            name: "Films",
            icon: "film.fill",
            kind: .films,
            ratingMode: .log,
            defaultView: .grid,
            itemSource: .tmdb,
            sortIndex: 2,
        )
        for collection in [cafes, countries, films] {
            repository.context.insert(collection)
        }

        let prufrock = repository.upsertItem(named: "Prufrock Coffee", externalRef: "mk:prufrock", in: cafes)
        repository.addEntry(to: prufrock, date: .now.addingTimeInterval(-2 * day), rating: 4.5, notes: "Flat white, perfect.")
        let japan = repository.upsertItem(named: "Japan", externalRef: "iso:JP", in: countries)
        repository.addEntry(to: japan, date: .now.addingTimeInterval(-40 * day), notes: "Cherry blossom in Kyoto.")
        repository.upsertItem(named: "Portugal", externalRef: "iso:PT", in: countries)
        let film = repository.upsertItem(named: "Perfect Days", externalRef: "tmdb:976893", in: films)
        repository.addEntry(to: film, date: .now.addingTimeInterval(-7 * day), rating: 5, notes: "Quietly wonderful.")
        try repository.save()
    }

    /// Adds `count` extra ranked cafés, one entry each, below any already ranked: enough keepsakes
    /// to measure the cabinet and riffle under load (`-stressItems N`, ADR-0004).
    public static func addStressItems(_ count: Int, to repository: Repository) throws {
        let cafes = try repository.collections(includeHidden: true).first { $0.kind == .cafes }
        guard let cafes, count > 0 else { return }
        let hour: TimeInterval = 3600
        let scores = RankScores.evenlySpaced(count: count)
        for index in 0 ..< count {
            let item = repository.upsertItem(named: "Café \(index + 1)", externalRef: "stress:\(index)", in: cafes)
            // Below the sample cafés (scored in thousands from 1,000 up).
            item.rankScore = scores[index] - RankScores.gap * Double(count + 1)
            repository.addEntry(to: item, date: .now.addingTimeInterval(-Double(index + 1) * hour))
        }
    }

    /// Fills the seeded built-in collections with a few sample items and entries, so screenshots
    /// and manual checks show drawers with keepsakes. Restaurants and Cities stay empty on
    /// purpose: they show the ghost state. Launch argument `-sampleData` (in-memory store only).
    public static func fillBuiltIns(_ repository: Repository) throws {
        let day: TimeInterval = 86400
        let byKind = try Dictionary(
            repository.collections(includeHidden: true).map { ($0.kind, $0) },
            uniquingKeysWith: { first, _ in first },
        )
        if let cafes = byKind[.cafes] {
            let ranked = ["Prufrock Coffee", "Monmouth", "Kaffeine", "Workshop"]
            for (index, (name, score)) in zip(ranked, RankScores.evenlySpaced(count: ranked.count)).enumerated() {
                let item = repository.upsertItem(named: name, externalRef: "sample:\(name)", in: cafes)
                item.rankScore = score
                repository.addEntry(to: item, date: .now.addingTimeInterval(-Double(index + 1) * 3 * day))
            }
        }
        if let countries = byKind[.countries] {
            let visited = [("Japan", "JP"), ("Peru", "PE"), ("Kenya", "KE"), ("Portugal", "PT")]
            let daysAgo = [400.0, 900.0, 1300.0, 60.0]
            for ((name, code), daysAgo) in zip(visited, daysAgo) {
                let item = repository.upsertItem(named: name, externalRef: "iso:\(code)", in: countries)
                item.countryCode = code
                repository.addEntry(to: item, date: .now.addingTimeInterval(-daysAgo * day))
            }
        }
        if let films = byKind[.films] {
            for (index, name) in ["Perfect Days", "Past Lives", "Aftersun"].enumerated() {
                let item = repository.upsertItem(named: name, externalRef: "sample:\(name)", in: films)
                repository.addEntry(to: item, date: .now.addingTimeInterval(-Double(index + 1) * 10 * day), rating: 5)
            }
        }
        if let airlines = byKind[.airlines] {
            let item = repository.upsertItem(named: "British Airways", externalRef: "iata:BA", in: airlines)
            repository.addEntry(to: item, date: .now.addingTimeInterval(-30 * day))
            repository.addEntry(to: item, date: .now.addingTimeInterval(-200 * day))
        }
        try repository.save()
    }
}
