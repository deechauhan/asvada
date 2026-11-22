import Foundation
import SwiftData
import Testing
@testable import Model

@MainActor
struct RelationshipTests {
    @Test func buildsCollectionItemEntryGraph() throws {
        let context = try makeContext()
        let cafes = ExperienceCollection(name: "Cafés", kind: .cafes, ratingMode: .ranked, itemSource: .mapkit)
        let cafe = Item(name: "Prufrock", externalRef: "mk:123", collection: cafes)
        let visit = Entry(rating: 4.5, notes: "Flat white", item: cafe)
        let tag = Tag(name: "coffee")
        let friend = Person(name: "Asha")
        visit.tags = [tag]
        visit.people = [friend]
        context.insert(cafes)
        try context.save()

        #expect(cafes.items?.count == 1)
        #expect(cafe.entries?.first?.notes == "Flat white")
        #expect(tag.entries?.count == 1)
        #expect(friend.entries?.first?.item?.name == "Prufrock")
    }

    @Test func deletingCollectionCascadesToItemsEntriesAndPhotos() throws {
        let context = try makeContext()
        let films = ExperienceCollection(name: "Films", kind: .films, ratingMode: .log)
        let film = Item(name: "Spirited Away", externalRef: "tmdb:129", collection: films)
        let viewing = Entry(item: film)
        _ = Photo(thumbnailData: Data([1, 2, 3]), entry: viewing)
        let tag = Tag(name: "anime")
        viewing.tags = [tag]
        context.insert(films)
        try context.save()

        context.delete(films)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Photo>()) == 0)
        // Tags are shared labels: they outlive the entries that used them.
        #expect(try context.fetchCount(FetchDescriptor<Tag>()) == 1)
    }

    @Test func deletingTripKeepsItsEntries() throws {
        let context = try makeContext()
        let trip = Trip(name: "Japan 2026")
        let entry = Entry()
        entry.trip = trip
        context.insert(trip)
        try context.save()

        context.delete(trip)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 1)
        #expect(try context.fetch(FetchDescriptor<Entry>()).first?.trip == nil)
    }
}
