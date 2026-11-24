import Foundation
import Model
import Ranking
import SwiftData
import Testing
@testable import Storage

@MainActor
struct RankingStorageTests {
    let container: ModelContainer
    let repository: Repository
    let cafes: ExperienceCollection

    init() throws {
        container = try AsvadaStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let match = try repository.collections().first { $0.kind == .cafes }
        cafes = try #require(match)
    }

    private func cafe(_ name: String) -> Item {
        repository.upsertItem(named: name, externalRef: "mk:\(name)", in: cafes)
    }

    private func names() -> [String] {
        repository.ranking(of: cafes).map(\.name)
    }

    /// Ranks `name` by answering each question from `taste` (higher is better).
    private func rank(_ name: String, taste: [String: Int]) throws {
        let newcomer = cafe(name)
        let ranked = repository.ranking(of: cafes).filter { $0.id != newcomer.id }
        var insertion = BinaryInsertion(count: ranked.count)
        while let index = insertion.comparisonIndex {
            let mine = try #require(taste[name])
            let theirs = try #require(taste[ranked[index].name])
            insertion.record(mine > theirs ? .better : .worse)
        }
        let position = try #require(insertion.position)
        repository.place(newcomer, at: position, in: cafes)
        try repository.save()
    }

    @Test func rankingFollowsTheAnswers() throws {
        let taste = ["Prufrock": 9, "Monmouth": 7, "Kaffeine": 8, "Workshop": 3, "Origin": 5, "Attendant": 6]
        for name in ["Monmouth", "Workshop", "Prufrock", "Origin", "Kaffeine", "Attendant"] {
            try rank(name, taste: taste)
        }
        #expect(names() == ["Prufrock", "Kaffeine", "Monmouth", "Attendant", "Origin", "Workshop"])
    }

    @Test func unrankedItemsStayOutOfTheRanking() {
        repository.place(cafe("Prufrock"), at: 0, in: cafes)
        _ = cafe("Not yet ranked")
        #expect(names() == ["Prufrock"])
    }

    @Test func placingMovesAnAlreadyRankedItem() {
        for (index, name) in ["A", "B", "C"].enumerated() {
            repository.place(cafe(name), at: index, in: cafes)
        }
        repository.place(cafe("C"), at: 0, in: cafes)
        #expect(names() == ["C", "A", "B"])
        repository.unrank(cafe("A"))
        #expect(names() == ["C", "B"])
    }

    @Test func crowdedScoresAreRebalancedInPlace() {
        // Scores as the old sample data had them: too close for a midpoint.
        let scored = [("Prufrock", 0.92), ("Monmouth", 0.81), ("Kaffeine", 0.74)]
        for (name, score) in scored {
            cafe(name).rankScore = score
        }
        repository.place(cafe("Origin"), at: 1, in: cafes)
        #expect(names() == ["Prufrock", "Origin", "Monmouth", "Kaffeine"])
        let scores = repository.ranking(of: cafes).compactMap(\.rankScore)
        #expect(scores == [4000, 3000, 2000, 1000])
    }
}
