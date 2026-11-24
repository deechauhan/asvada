import Testing
@testable import Ranking

struct RankScoresTests {
    private func isStrictlyDescending(_ scores: [Double]) -> Bool {
        zip(scores, scores.dropFirst()).allSatisfy { $0 > $1 }
    }

    @Test func evenlySpacedCountsDownInGaps() {
        #expect(RankScores.evenlySpaced(count: 3) == [3000, 2000, 1000])
        #expect(RankScores.evenlySpaced(count: 0).isEmpty)
    }

    @Test func theFirstItemGetsOneGap() {
        #expect(RankScores.place(at: 0, among: []) == .init(score: 1000, rebalanced: nil))
    }

    @Test func endsExtendByAGap() {
        let scores: [Double] = [3000, 2000, 1000]
        #expect(RankScores.place(at: 0, among: scores).score == 4000)
        #expect(RankScores.place(at: 3, among: scores).score == 0)
    }

    @Test func aNewcomerTakesTheMidpointAndNobodyElseMoves() {
        let placement = RankScores.place(at: 1, among: [3000, 2000, 1000])
        #expect(placement.score == 2500)
        #expect(placement.rebalanced == nil)
    }

    @Test func crowdedNeighboursRebalanceEvenly() {
        let placement = RankScores.place(at: 1, among: [2001, 2000, 1000])
        #expect(placement.rebalanced == [4000, 2000, 1000])
        #expect(placement.score == 3000)
    }

    @Test(arguments: [[1000, 1000], [1000, 2000], [.nan, 10], [.infinity, 10]] as [[Double]])
    func tiedOrUnorderedOrBrokenScoresAreRenumbered(scores: [Double]) {
        let placement = RankScores.place(at: 2, among: scores)
        #expect(placement.rebalanced == [3000, 2000])
        #expect(placement.score == 1000)
    }

    @Test func repeatedInsertsIntoOneSpotRebalanceWithinAboutTenSteps() {
        var scores: [Double] = [2000, 1000]
        var rebalances = 0
        for _ in 0 ..< 10 {
            let placement = RankScores.place(at: 1, among: scores)
            if let rebalanced = placement.rebalanced {
                scores = rebalanced
                rebalances += 1
            }
            scores.insert(placement.score, at: 1)
            #expect(isStrictlyDescending(scores))
        }
        #expect(rebalances >= 1)
    }

    /// Property: thousands of random inserts keep every score finite and the list strictly
    /// descending, with each newcomer exactly where it was placed and everyone else in order.
    @Test func randomInsertsKeepTheOrder() {
        var random = SeededGenerator(seed: 1000)
        var ranking: [(label: Int, score: Double)] = []
        var rebalances = 0
        for label in 0 ..< 3000 {
            // Mostly near the top, as favourites get compared most, so gaps run out sometimes.
            let position = Bool.random(using: &random)
                ? Int.random(in: 0 ... min(2, ranking.count), using: &random)
                : Int.random(in: 0 ... ranking.count, using: &random)
            let before = ranking.map(\.label)
            let placement = RankScores.place(at: position, among: ranking.map(\.score))
            if let rebalanced = placement.rebalanced {
                #expect(rebalanced.count == ranking.count)
                ranking = zip(ranking, rebalanced).map { ($0.label, $1) }
                rebalances += 1
            }
            ranking.insert((label, placement.score), at: position)
            let scores = ranking.map(\.score)
            // Hoisted: #expect splits a call into a closure that may throw, and allSatisfy rethrows.
            let allFinite = scores.allSatisfy(\.isFinite)
            #expect(allFinite)
            #expect(isStrictlyDescending(scores), "after inserting \(label) at \(position)")
            var expected = before
            expected.insert(label, at: position)
            let labels = ranking.map(\.label)
            #expect(labels == expected)
        }
        #expect(rebalances > 0, "the test should exercise rebalancing")
    }

    /// The engine end to end: binary insertion finds the place, scores keep it.
    @Test func insertionAndScoresTogetherSortByTaste() {
        var random = SeededGenerator(seed: 7)
        // Hidden "true taste" per item; the oracle answers by it.
        let tastes = (0 ..< 300).map { _ in Double.random(in: 0 ... 1, using: &random) }
        var ranking: [(taste: Double, score: Double)] = []
        for taste in tastes {
            var insertion = BinaryInsertion(count: ranking.count)
            while let index = insertion.comparisonIndex {
                insertion.record(taste > ranking[index].taste ? .better : .worse)
            }
            let position = insertion.position ?? 0
            let placement = RankScores.place(at: position, among: ranking.map(\.score))
            if let rebalanced = placement.rebalanced {
                ranking = zip(ranking, rebalanced).map { ($0.taste, $1) }
            }
            ranking.insert((taste, placement.score), at: position)
        }
        let byScore = ranking.sorted { $0.score > $1.score }.map(\.taste)
        #expect(byScore == tastes.sorted(by: >))
    }
}
