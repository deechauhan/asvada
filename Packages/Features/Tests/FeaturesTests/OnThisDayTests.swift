import Foundation
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct OnThisDayTests {
    private struct Store {
        let container: ModelContainer
        let repository: Repository
        let films: ExperienceCollection
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private func store() throws -> Store {
        let container = try ArtifactsStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        let films = ExperienceCollection(name: "Films", kind: .films, ratingMode: .log)
        repository.context.insert(films)
        return Store(container: container, repository: repository, films: films)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
    }

    @discardableResult
    private func watch(_ name: String, on day: Date, in store: Store) -> Entry {
        let item = store.repository.upsertItem(named: name, externalRef: nil, in: store.films)
        return store.repository.addEntry(to: item, date: day)
    }

    private func entries(_ store: Store) -> [Entry] {
        (store.films.items ?? []).flatMap { $0.entries ?? [] }
    }

    @Test func theSameDayInEarlierYearsMatchesMostRecentFirst() throws {
        let store = try store()
        watch("Past Lives", on: date(2023, 11, 26), in: store)
        watch("Aftersun", on: date(2025, 11, 26), in: store)
        watch("Today", on: date(2026, 11, 26), in: store)
        watch("Day before", on: date(2025, 11, 25), in: store)
        let found = OnThisDay.anniversaries(in: entries(store), on: date(2026, 11, 26), calendar: utc)
        #expect(found.map(\.item.name) == ["Aftersun", "Past Lives"])
        #expect(found.map(\.yearsAgo) == [1, 3])
    }

    @Test func theTwentyNinthOfFebruaryIsRememberedOnTheTwentyEighthInOtherYears() throws {
        let store = try store()
        watch("Leap film", on: date(2024, 2, 29), in: store)
        let onThe28th = OnThisDay.anniversaries(in: entries(store), on: date(2025, 2, 28), calendar: utc)
        #expect(onThe28th.map(\.item.name) == ["Leap film"])
        // In a leap year it waits for the 29th itself.
        #expect(OnThisDay.anniversaries(in: entries(store), on: date(2028, 2, 28), calendar: utc).isEmpty)
        #expect(OnThisDay.anniversaries(in: entries(store), on: date(2028, 2, 29), calendar: utc).count == 1)
    }

    @Test func headlinesSayHowLongAgoAndHowMany() throws {
        let store = try store()
        watch("Aftersun", on: date(2025, 11, 26), in: store)
        let one = OnThisDay.anniversaries(in: entries(store), on: date(2026, 11, 26), calendar: utc)
        #expect(OnThisDay.headline(one) == "A year ago, you savoured Aftersun.")

        watch("Zama", on: date(2025, 11, 26), in: store)
        let two = OnThisDay.anniversaries(in: entries(store), on: date(2026, 11, 26), calendar: utc)
        #expect(OnThisDay.headline(two) == "A year ago, you savoured Aftersun and 1 more.")

        watch("Old", on: date(2022, 11, 26), in: store)
        let mixed = OnThisDay.anniversaries(in: entries(store), on: date(2026, 11, 26), calendar: utc)
        #expect(OnThisDay.headline(mixed) == "On this day, you savoured Aftersun and 2 more.")
        #expect(OnThisDay.headline([]) == nil)
        #expect(OnThisDay.ago(1) == "1 year ago")
        #expect(OnThisDay.ago(4) == "4 years ago")
    }

    @Test func aDrawerKnowsItsOwnAnniversaries() throws {
        let store = try store()
        watch("Aftersun", on: date(2025, 11, 26), in: store)
        #expect(store.films.anniversaries(on: date(2026, 11, 26), calendar: utc).count == 1)
        #expect(store.films.anniversaries(on: date(2026, 11, 27), calendar: utc).isEmpty)
    }

    @Test func theReminderIsForNineTomorrowMorningWithTheHeadline() throws {
        let when = try #require(OnThisDayReminder.fireDate(after: date(2026, 11, 26), calendar: utc))
        #expect(when.year == 2026)
        #expect(when.month == 11)
        #expect(when.day == 27)
        #expect(when.hour == OnThisDayReminder.hour)

        let store = try store()
        watch("Aftersun", on: date(2025, 11, 27), in: store)
        let tomorrow = OnThisDay.anniversaries(in: entries(store), on: date(2026, 11, 27), calendar: utc)
        let text = try #require(OnThisDayReminder.text(for: tomorrow))
        #expect(text.title == "On this day")
        #expect(text.body == "A year ago, you savoured Aftersun.")
        #expect(OnThisDayReminder.text(for: [])?.body == nil)
    }
}
