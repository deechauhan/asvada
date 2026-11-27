import Foundation
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct TastingMenuTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try AsvadaStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int = 10) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
    }

    private func collection(_ kind: CollectionKind) throws -> ExperienceCollection {
        try #require(try repository.collections().first { $0.kind == kind })
    }

    @discardableResult
    private func add(
        _ name: String,
        to collection: ExperienceCollection,
        on days: [Date],
        rating: Double? = nil,
        rank: Double? = nil,
    ) -> Item {
        let item = repository.upsertItem(named: name, externalRef: nil, in: collection)
        item.rankScore = rank
        for day in days {
            repository.addEntry(to: item, date: day, rating: rating)
        }
        return item
    }

    private func menu(_ year: Int) throws -> TastingMenu {
        try TastingMenu(year: year, collections: repository.collections(), calendar: utc)
    }

    @Test func aFullYearIsServedInFiveCourses() throws {
        try add("Monmouth", to: collection(.cafes), on: [date(2026, 2)])
        try add("Prufrock", to: collection(.cafes), on: [date(2026, 1, 3)])
        try add("Japan", to: collection(.countries), on: [date(2026, 4)])
        try add("Peru", to: collection(.countries), on: [date(2026, 8)])
        try add("Old country", to: collection(.countries), on: [date(2024, 5), date(2026, 3)])
        try add("Dishoom", to: collection(.restaurants), on: [date(2026, 6)], rank: 2000)
        try add("Hoppers", to: collection(.restaurants), on: [date(2026, 7)], rank: 1000)
        try add("Past Lives", to: collection(.films), on: [date(2026, 3)], rating: 4)
        try add("Perfect Days", to: collection(.films), on: [date(2026, 5)], rating: 5)
        try add("TAP", to: collection(.airlines), on: [date(2026, 4)])
        try add("British Airways", to: collection(.airlines), on: [date(2026, 4), date(2026, 9)])

        let menu = try menu(2026)
        #expect(menu.courses.map(\.title) == ["Amuse-bouche", "Entrée", "Main", "Dessert", "Digestif"])
        #expect(menu.courses.map(\.dish) == ["Prufrock", "Japan and Peru", "Dishoom", "Perfect Days", "British Airways"])
        #expect(menu.courses[0].note.hasPrefix("your first coffee, "))
        #expect(menu.courses[0].note.contains("January"))
        #expect(menu.courses[1].note == "2 new countries")
        #expect(menu.courses[4].note == "2 flights")
        #expect(menu.total == 12)
    }

    @Test func aCourseWithNothingToServeIsLeftOff() throws {
        try add("Perfect Days", to: collection(.films), on: [date(2026, 5), date(2026, 6)])
        let menu = try menu(2026)
        #expect(menu.courses.map(\.title) == ["Dessert"])
        #expect(menu.courses.first?.note == "the film of the year, seen 2 times")
        #expect(try self.menu(2025).isEmpty)
    }

    @Test func theYearShownFirstIsThisOneOnceItHasAnything() throws {
        let films = try collection(.films)
        let collections = try repository.collections()
        #expect(TastingMenu.defaultYear(collections: collections, now: date(2027, 1, 2), calendar: utc) == 2026)
        add("New year's film", to: films, on: [date(2027, 1, 1)])
        #expect(TastingMenu.defaultYear(collections: collections, now: date(2027, 1, 2), calendar: utc) == 2027)
        add("Old film", to: films, on: [date(2024, 1)])
        #expect(TastingMenu.years(collections: collections, calendar: utc) == [2027, 2024])
    }

    @Test func pagesAreTheCoverEachCourseThenTheMenu() throws {
        try add("Perfect Days", to: collection(.films), on: [date(2026, 5)])
        let pages = try MenuPage.pages(of: menu(2026))
        #expect(pages.count == 3)
        #expect(pages.first == .cover)
        #expect(pages.last == .menu)
        #expect(try MenuPage.pages(of: menu(2020)) == [.cover])
    }

    @Test func theCoverCountsTheYear() throws {
        #expect(try YearText.cover(menu(2020)) == "Nothing savoured in 2020 yet.")
        try add("Perfect Days", to: collection(.films), on: [date(2026, 5)])
        #expect(try YearText.cover(menu(2026)) == "1 thing savoured, in one course.")
    }
}
