/// Gap-based scores for a ranked list, so placing an item rarely touches the others.
///
/// Higher is better. A fresh list is scored `gap × n … 2 × gap, gap` from the top. A newcomer takes
/// the midpoint of its neighbours, or one `gap` beyond the end it joins. When two neighbours have
/// drifted closer than `minimumGap`, the whole list is renumbered evenly (a rebalance). With a
/// 1,000 gap that takes about ten inserts into the same spot, and the renumbering is one pass.
public enum RankScores {
    /// The spacing between neighbours in a fresh or rebalanced list.
    public static let gap: Double = 1000
    /// Neighbours closer than this force a rebalance rather than a midpoint.
    public static let minimumGap: Double = 1

    /// Where a newcomer's score comes from.
    public struct Placement: Sendable, Equatable {
        /// The newcomer's score.
        public let score: Double
        /// New scores for the items already ranked, best first, when they had to be renumbered;
        /// `nil` when they keep theirs.
        public let rebalanced: [Double]?
    }

    /// Evenly spaced scores for `count` items, best first: `gap × count` down to `gap`.
    public static func evenlySpaced(count: Int) -> [Double] {
        (0 ..< max(count, 0)).map { Double(count - $0) * gap }
    }

    /// The score for a newcomer placed at `position` (0 is the top) among items whose current
    /// `scores` are listed best first.
    ///
    /// Scores that are out of order, tied, or too close around `position` are renumbered first, so
    /// the result always keeps the list strictly descending.
    public static func place(at position: Int, among scores: [Double]) -> Placement {
        precondition((0 ... scores.count).contains(position), "Position \(position) is outside 0...\(scores.count)")
        if let score = score(at: position, among: scores) {
            return Placement(score: score, rebalanced: nil)
        }
        var spaced = evenlySpaced(count: scores.count + 1)
        let newcomer = spaced.remove(at: position)
        return Placement(score: newcomer, rebalanced: spaced)
    }

    /// The midpoint (or end) score for `position`, or `nil` if the neighbours leave no room.
    private static func score(at position: Int, among scores: [Double]) -> Double? {
        guard isUsable(scores) else { return nil }
        let above = position > 0 ? scores[position - 1] : nil
        let below = position < scores.count ? scores[position] : nil
        switch (above, below) {
        case (nil, nil):
            return gap
        case let (above?, nil):
            return above - gap
        case let (nil, below?):
            return below + gap
        case let (above?, below?):
            guard above - below >= 2 * minimumGap else { return nil }
            return (above + below) / 2
        }
    }

    /// Finite and strictly descending: anything else gets renumbered.
    private static func isUsable(_ scores: [Double]) -> Bool {
        guard scores.allSatisfy(\.isFinite) else { return false }
        return zip(scores, scores.dropFirst()).allSatisfy { $0 > $1 }
    }
}
