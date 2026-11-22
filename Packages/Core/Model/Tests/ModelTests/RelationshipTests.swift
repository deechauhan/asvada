import Foundation
import SwiftData
import Testing
@testable import Model

@MainActor
struct RelationshipTests {
    @Test func buildsCollectionItemEntryGraph() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let cafes = ExperienceCollection(name: "Cafés", kind: .cafes, ratingMode: .ranked, itemSource: .mapkit)
        let cafe = Item(name: "Prufrock", externalRef: "mk:123")
        let visit = Entry(rating: 4.5, notes: "Flat white")
        let tag = ModelTag(name: "coffee")
        let friend = Person(name: "Asha")
        for model in [cafes, cafe, visit, tag, friend] as [any PersistentModel] {
            context.insert(model)
        }
        cafe.collection = cafes
        visit.item = cafe
        visit.tags = [tag]
        visit.people = [friend]
        try context.save()

        #expect(cafes.items?.count == 1)
        #expect(cafe.entries?.first?.notes == "Flat white")
        #expect(tag.entries?.count == 1)
        #expect(friend.entries?.first?.item?.name == "Prufrock")
    }

    @Test func deletingCollectionCascadesToItemsEntriesAndPhotos() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let films = ExperienceCollection(name: "Films", kind: .films, ratingMode: .log)
        let film = Item(name: "Spirited Away", externalRef: "tmdb:129")
        let viewing = Entry()
        let photo = Photo(thumbnailData: Data([1, 2, 3]))
        let tag = ModelTag(name: "anime")
        for model in [films, film, viewing, photo, tag] as [any PersistentModel] {
            context.insert(model)
        }
        film.collection = films
        viewing.item = film
        photo.entry = viewing
        viewing.tags = [tag]
        try context.save()

        context.delete(films)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Photo>()) == 0)
        // Tags are shared labels: they outlive the entries that used them.
        #expect(try context.fetchCount(FetchDescriptor<ModelTag>()) == 1)
    }

    @Test func deletingTripKeepsItsEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let trip = Trip(name: "Japan 2026")
        let entry = Entry()
        context.insert(trip)
        context.insert(entry)
        entry.trip = trip
        try context.save()

        context.delete(trip)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 1)
        #expect(try context.fetch(FetchDescriptor<Entry>()).first?.trip == nil)
    }
}
