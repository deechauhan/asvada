import DesignSystem
import Foundation
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct RiffleIndexTests {
    /// An in-memory store and a collection to fill. Hold on to the store for the whole test.
    private struct Store {
        let container: ModelContainer
        let repository: Repository
        let collection: ExperienceCollection
    }

    private func store(_ mode: RatingMode) throws -> Store {
        let container = try AsvadaStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        let collection = ExperienceCollection(name: "Things", ratingMode: mode)
        repository.context.insert(collection)
        return Store(container: container, repository: repository, collection: collection)
    }

    private func date(_ year: Int, _ month: Int = 6, _ day: Int = 1) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    @discardableResult
    private func add(
        _ name: String,
        to store: Store,
        on dates: [Date] = [],
        rating: Double? = nil,
        rank: Double? = nil,
    ) -> Item {
        let item = store.repository.upsertItem(named: name, externalRef: nil, in: store.collection)
        item.rankScore = rank
        for day in dates {
            store.repository.addEntry(to: item, date: day, rating: rating)
        }
        return item
    }

    @Test func rankedDrawersRunBestFirstWithNumberedTabs() throws {
        let store = try store(.ranked)
        add("Monmouth", to: store, rank: 2000)
        add("Prufrock", to: store, rank: 3000)
        add("Kaffeine", to: store, rank: 1000)
        let index = RiffleIndex.make(items: store.collection.items ?? [], mode: .ranked, calendar: utc)
        #expect(index.cards.map(\.tab) == ["No. 1", "No. 2", "No. 3"])
        #expect(index.cards.compactMap(\.item?.name) == ["Prufrock", "Monmouth", "Kaffeine"])
        #expect(index.cards.first?.spoken == "No. 1, Prufrock")
        #expect(index.marks.map(\.label) == ["No. 1", "No. 2", "No. 3"])
        #expect(index.cards.allSatisfy { !$0.isGuide })
    }

    @Test func logsRunNewestFirstUnderAGuideCardPerYear() throws {
        let store = try store(.log)
        add("Past Lives", to: store, on: [date(2025, 3)])
        add("Perfect Days", to: store, on: [date(2026, 1), date(2026, 5)])
        add("Aftersun", to: store, on: [date(2025, 11)])
        let index = RiffleIndex.make(items: store.collection.items ?? [], mode: .log, calendar: utc)

        #expect(index.cards.map(\.isGuide) == [true, false, true, false, false])
        #expect(index.cards.first?.tab == "2026")
        #expect(index.cards.first?.spoken == "2026, 1 in this year")
        #expect(index.cards.compactMap(\.item?.name) == ["Perfect Days", "Aftersun", "Past Lives"])
        // Rewatched stubs say how many times.
        #expect(index.cards[1].tab.hasSuffix(" ×2"))
        #expect(index.marks == [RiffleMark(label: "2026", cardIndex: 0), RiffleMark(label: "2025", cardIndex: 2)])
    }

    @Test func starredDrawersGroupByRelishBestFirstWithTheUnratedLast() throws {
        let store = try store(.stars)
        add("Lisbon", to: store, on: [date(2024)], rating: 5)
        add("Porto", to: store, on: [date(2025)], rating: 3)
        add("Braga", to: store)
        add("Sintra", to: store, on: [date(2023)], rating: 5)
        let index = RiffleIndex.make(items: store.collection.items ?? [], mode: .stars, calendar: utc)

        #expect(index.marks.map(\.label) == ["Unforgettable", "Good", RiffleIndex.unrated])
        #expect(index.cards.first?.spoken == "Unforgettable, 2 keepsakes")
        #expect(index.cards.compactMap(\.item?.name) == ["Lisbon", "Sintra", "Porto", "Braga"])
        #expect(index.cards[1].spoken == "Unforgettable, Lisbon")
    }

    @Test func checklistsMarkTheRailByInitial() throws {
        let store = try store(.checklist)
        add("Japan", to: store, on: [date(2026)])
        add("Jordan", to: store, on: [date(2025)])
        add("Peru", to: store, on: [date(2024)])
        let index = RiffleIndex.make(items: store.collection.items ?? [], mode: .checklist, calendar: utc)
        #expect(index.marks == [RiffleMark(label: "J", cardIndex: 0), RiffleMark(label: "P", cardIndex: 2)])
    }

    @Test func aLongRailShowsEveryFewMarksAndAlwaysTheFirst() {
        let marks = (0 ..< 30).map { RiffleMark(label: "No. \($0 + 1)", cardIndex: $0) }
        let thinned = RiffleIndex.thinned(marks)
        #expect(thinned.count <= RiffleIndex.maximumMarks)
        #expect(thinned.first == marks.first)
        #expect(RiffleIndex.thinned(Array(marks.prefix(5))) == Array(marks.prefix(5)))
    }

    @Test func tabsStepAcrossTheThirds() {
        #expect((0 ..< 6).map(RiffleIndex.tabSlot) == [0, 1, 2, 0, 1, 2])
    }

    @Test func anItemIsFoundByItsCard() throws {
        let store = try store(.log)
        let film = add("Aftersun", to: store, on: [date(2025)])
        let index = RiffleIndex.make(items: store.collection.items ?? [], mode: .log, calendar: utc)
        // After the 2025 guide card.
        #expect(index.index(of: film) == 1)
    }
}

struct RifflePagerTests {
    @Test func thumbingDownMovesForwardOneCardPerPitch() {
        let pager = RifflePager(count: 10, position: 2)
        #expect(pager.position(dragging: RifflePager.pitch, from: 2) == 3)
        #expect(pager.position(dragging: -RifflePager.pitch * 2, from: 2) == 0)
    }

    @Test func theEndsRubberBand() {
        let pager = RifflePager(count: 3)
        let pastStart = pager.position(dragging: -RifflePager.pitch * 3, from: 0)
        #expect(pastStart < 0 && pastStart > -1)
        let pastEnd = pager.position(dragging: RifflePager.pitch * 10, from: 2)
        #expect(pastEnd > 2 && pastEnd < 3)
    }

    @Test func aReleaseSnapsToAWholeCardAndAFlingCarriesFurther() {
        var pager = RifflePager(count: 20, position: 3.3)
        #expect(pager.restingPosition(afterReleaseAt: 0) == 3)
        // 1,000 pt/s for 0.18 s is 180 pt, about three cards.
        #expect(pager.restingPosition(afterReleaseAt: 1000) == 6)
        pager.position = 18.6
        #expect(pager.restingPosition(afterReleaseAt: 5000) == 19)
        pager.position = 0.2
        #expect(pager.restingPosition(afterReleaseAt: -5000) == 0)
    }

    @Test func theFrontIsTheNearestCard() {
        #expect(RifflePager(count: 5, position: 1.4).frontIndex == 1)
        #expect(RifflePager(count: 5, position: 1.6).frontIndex == 2)
        #expect(RifflePager(count: 5, position: -0.3).frontIndex == 0)
        #expect(RifflePager(count: 5, position: 9).frontIndex == 4)
        #expect(RifflePager(count: 0).frontIndex == 0)
    }

    @Test func onlyTheCardsNearTheFrontAreDrawn() {
        let pager = RifflePager(count: 1000, position: 500)
        let visible = pager.visibleIndices()
        #expect(visible.first == 498)
        #expect(visible.last == 507)
        #expect(RifflePager(count: 3).visibleIndices() == [0, 1, 2])
        #expect(RifflePager(count: 0).visibleIndices().isEmpty)
    }
}

struct RiffleCardGeometryTests {
    @Test func theFrontCardStandsUpright() {
        let front = RiffleCardGeometry(offset: 0)
        #expect(front.rotation == 0)
        #expect(front.y == 0)
        #expect(front.scale == 1)
        #expect(front.opacity == 1)
    }

    @Test func cardsBehindStepUpSoTheirTabsShow() {
        let second = RiffleCardGeometry(offset: 1)
        let third = RiffleCardGeometry(offset: 2)
        #expect(second.y == -RiffleCardGeometry.step)
        #expect(third.y == -RiffleCardGeometry.step * 2)
        #expect(third.scale < second.scale)
        #expect(third.zIndex < second.zIndex)
        #expect(!RiffleCardGeometry(offset: 9).isVisible)
    }

    @Test func aCardFlipsTowardYouAboutItsBottomEdge() {
        let half = RiffleCardGeometry(offset: -0.5)
        #expect(half.rotation == RiffleCardGeometry.flipAngle / 2)
        #expect(half.zIndex > RiffleCardGeometry(offset: 0).zIndex)
        #expect(!RiffleCardGeometry(offset: -1).isVisible)
    }

    @Test func reduceMotionSlidesInsteadOfTurning() {
        let half = RiffleCardGeometry(offset: -0.5, reduceMotion: true)
        #expect(half.rotation == 0)
        #expect(half.y > 0)
        #expect(half.opacity == 0.5)
    }
}
