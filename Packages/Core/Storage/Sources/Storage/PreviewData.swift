import Foundation
import Model
import SwiftData

/// An in-memory store filled with sample data, for SwiftUI previews and tests.
@MainActor
public enum PreviewData {
    /// A fresh in-memory container with sample collections, items and entries.
    public static func makeContainer() throws -> ModelContainer {
        let container = try AsvadaStore.makeContainer(.inMemory)
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
}
