import Foundation
import Model
import Storage
import SwiftData
import Testing
@testable import Features

/// A repeatable random source, so picks can be checked.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

@MainActor
struct LuckyDipTests {
    let container: ModelContainer
    let repository: Repository
    let films: ExperienceCollection
    let cafes: ExperienceCollection

    init() throws {
        container = try ArtifactsStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        films = ExperienceCollection(name: "Films", kind: .films, ratingMode: .log)
        cafes = ExperienceCollection(name: "Cafés", kind: .cafes, ratingMode: .ranked)
        repository.context.insert(films)
        repository.context.insert(cafes)
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    private let now = Date(timeIntervalSinceReferenceDate: 816_000_000) // late November 2026

    @discardableResult
    private func add(_ name: String, to collection: ExperienceCollection, daysAgo: Double, notes: String = "") -> Item {
        let item = repository.upsertItem(named: name, externalRef: nil, in: collection)
        repository.addEntry(to: item, date: now.addingTimeInterval(-daysAgo * 86400), notes: notes)
        return item
    }

    @Test func forgottenNotedAndAnniversaryKeepsakesWeighMore() {
        let recent = add("Recent", to: films, daysAgo: 3)
        let forgotten = add("Forgotten", to: films, daysAgo: 120)
        let noted = add("Noted", to: films, daysAgo: 3, notes: "Rain on the window")
        let yearAgo = add("A year ago", to: films, daysAgo: 365)
        #expect(LuckyDip.weight(of: recent, now: now, calendar: utc) == 1)
        #expect(LuckyDip.weight(of: forgotten, now: now, calendar: utc) == 2)
        #expect(LuckyDip.weight(of: noted, now: now, calendar: utc) == 2)
        // An anniversary that's also forgotten: ×2 ×2.
        #expect(LuckyDip.weight(of: yearAgo, now: now, calendar: utc) == 4)
    }

    @Test func itNeverHandsOutTheSameKeepsakeTwiceInARow() {
        add("One", to: films, daysAgo: 3)
        add("Two", to: cafes, daysAgo: 3)
        var generator = SeededGenerator(state: 42)
        var last: UUID?
        for _ in 0 ..< 50 {
            let picked = LuckyDip.pick(from: [films, cafes], last: last, now: now, calendar: utc, using: &generator)
            #expect(picked != nil)
            #expect(picked?.id != last)
            last = picked?.id
        }
    }

    @Test func aLoneKeepsakeCanComeUpAgainAndEmptyDrawersGiveNothing() {
        let empty = ExperienceCollection(name: "Empty")
        repository.context.insert(empty)
        var generator = SeededGenerator(state: 7)
        #expect(LuckyDip.pick(from: [empty], last: nil, now: now, calendar: utc, using: &generator) == nil)
        let only = add("Only", to: films, daysAgo: 3)
        #expect(LuckyDip.pick(from: [films, empty], last: only.id, now: now, calendar: utc, using: &generator)?.id == only.id)
    }

    @Test func heavierKeepsakesComeUpMoreOften() {
        let light = add("Light", to: films, daysAgo: 3)
        let heavy = add("Heavy", to: films, daysAgo: 365, notes: "x")
        var generator = SeededGenerator(state: 1)
        let heavyCount = (0 ..< 900).filter { _ in
            LuckyDip.pick(from: [films], last: nil, now: now, calendar: utc, using: &generator)?.id == heavy.id
        }.count
        // ×8 against ×1: about 800 of 900.
        #expect(heavyCount > 700)
        #expect(light.id != heavy.id)
    }

    @Test func theSpinTurnsTwiceThenForwardToTheDrawer() {
        // From drawer 1 of 8 to drawer 6: two turns (16) and five more.
        #expect(LuckyDip.spinTarget(from: 1, to: 6, count: 8) == 1 + 16 + 5)
        // Going "back" to drawer 0 still turns forward: 16 + 7.
        #expect(LuckyDip.spinTarget(from: 1, to: 0, count: 8) == 1 + 16 + 7)
        // Landing on the drawer already in front: just the two turns.
        #expect(LuckyDip.spinTarget(from: 3, to: 3, count: 8) == 3 + 16)
        #expect(LuckyDip.spinTarget(from: 2, to: 0, count: 0) == 2)
    }

    @Test func theClicksSlowDownAndTheLastLandsAtTheEnd() {
        let times = LuckyDip.detentTimes(steps: 20, duration: 2.46)
        #expect(times.count == 20)
        #expect(abs((times.last ?? 0) - 2.46) < 0.0001)
        let gaps = zip(times.dropFirst(), times).map { $0 - $1 }
        // Each gap is longer than the one before.
        #expect(zip(gaps.dropFirst(), gaps).allSatisfy { $0 > $1 })
        #expect(LuckyDip.detentTimes(steps: 0, duration: 2).isEmpty)
    }

    @Test func voiceOverHearsWhereItCameFrom() {
        let item = add("Perfect Days", to: films, daysAgo: 3)
        #expect(LuckyDip.announcement(for: item).hasPrefix("From your Films drawer: Perfect Days, savoured "))
    }
}
