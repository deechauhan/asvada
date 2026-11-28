import Foundation
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct JournalMonthsTests {
    let container: ModelContainer
    let repository: Repository
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    init() throws {
        container = try ArtifactsStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private func collection(_ kind: CollectionKind) throws -> ExperienceCollection {
        try #require(try repository.collections().first { $0.kind == kind })
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    @discardableResult
    private func log(_ name: String, in kind: CollectionKind, on day: Date) throws -> Entry {
        let item = try repository.upsertItem(named: name, externalRef: nil, in: collection(kind))
        return repository.addEntry(to: item, date: day)
    }

    @Test func entriesGroupByMonthNewestFirst() throws {
        try log("Old", in: .cafes, on: date(2025, 12, 30))
        try log("Newest", in: .cafes, on: date(2026, 11, 25))
        try log("Middle", in: .films, on: date(2026, 11, 2))
        try log("Other month", in: .cafes, on: date(2026, 10, 31))

        let months = try JournalMonths.group(repository.recentEntries().shuffled(), calendar: calendar)

        #expect(months.map(\.id) == ["2026-11", "2026-10", "2025-12"])
        #expect(months[0].entries.map { $0.item?.name } == ["Newest", "Middle"])
        #expect(calendar.component(.day, from: months[0].start) == 1)
    }

    @Test func aMonthSaysWhatItHeld() throws {
        try log("A", in: .cafes, on: date(2026, 11, 1))
        try log("B", in: .cafes, on: date(2026, 11, 2))
        try log("C", in: .cafes, on: date(2026, 11, 3))
        try log("Japan", in: .countries, on: date(2026, 11, 4))
        try log("Perfect Days", in: .films, on: date(2026, 11, 5))
        try log("Past Lives", in: .films, on: date(2026, 11, 6))

        let month = try #require(JournalMonths.group(repository.recentEntries(), calendar: calendar).first)

        #expect(month.summary == "3 cafés · 2 films · 1 country")
    }

    @Test func nounsAgreeWithTheirCount() throws {
        #expect(try JournalMonths.phrase(count: 1, collection: collection(.cafes)) == "1 café")
        #expect(try JournalMonths.phrase(count: 2, collection: collection(.airlines)) == "2 flights")
        #expect(try JournalMonths.phrase(count: 1, collection: collection(.cities)) == "1 city")
        #expect(try JournalMonths.phrase(count: 4, collection: collection(.restaurants)) == "4 restaurants")
        let concerts = ExperienceCollection(name: "Concerts", kind: .custom)
        #expect(JournalMonths.phrase(count: 2, collection: concerts) == "2 in Concerts")
    }

    @Test func entriesWithoutAThingAreLeftOut() throws {
        let orphan = try Entry(date: date(2026, 11, 1))
        repository.context.insert(orphan)
        try log("Kept", in: .cafes, on: date(2026, 11, 2))

        let months = try JournalMonths.group(repository.recentEntries(), calendar: calendar)

        #expect(months.count == 1)
        #expect(months[0].entries.count == 1)
    }

    @Test func nothingLoggedMeansNoMonths() {
        #expect(JournalMonths.group([]).isEmpty)
    }
}
