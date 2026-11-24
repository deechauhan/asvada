/// The answer to "which was better?" when a newcomer meets an item already in the ranking.
public enum Verdict: Sendable, Equatable {
    /// The newcomer was better than the item shown.
    case better
    /// The item shown was better than the newcomer.
    case worse
}

/// Places one new item into a ranked list by asking "which was better?" against the middle of the
/// part still in question, halving it each time. The list is best first: index 0 is the favourite.
///
/// It never asks more than `ceil(log2(n + 1))` questions for a list of `n`: 3 for 7 cafés, 7 for
/// 100. Answers can be taken back one at a time with `undo()`, so a mis-tap costs nothing.
///
/// ```swift
/// var insertion = BinaryInsertion(count: ranked.count)
/// while let index = insertion.comparisonIndex {
///     insertion.record(ask(newcomer, versus: ranked[index]))
/// }
/// ranked.insert(newcomer, at: insertion.position!)
/// ```
public struct BinaryInsertion: Sendable, Equatable {
    /// How many items were already ranked.
    public let count: Int
    /// The slots the newcomer could still land in: `lowerBound` is the best place still possible,
    /// `upperBound` the worst. Placed when they meet.
    public private(set) var candidates: ClosedRange<Int>
    /// Earlier `candidates`, one per answer, for `undo()`.
    private var history: [ClosedRange<Int>] = []

    /// Starts placing a newcomer into a list of `count` ranked items.
    public init(count: Int) {
        precondition(count >= 0, "A ranked list can't have a negative count")
        self.count = count
        candidates = 0 ... count
    }

    /// The most questions placing an item can take in a list of `count`: `ceil(log2(count + 1))`.
    public static func maximumComparisons(forCount count: Int) -> Int {
        guard count > 0 else { return 0 }
        // The bit width of `count` is ceil(log2(count + 1)) for count ≥ 1.
        return Int.bitWidth - count.leadingZeroBitCount
    }

    /// The index of the ranked item to compare the newcomer with next, or `nil` once placed.
    public var comparisonIndex: Int? {
        guard !isPlaced else { return nil }
        return (candidates.lowerBound + candidates.upperBound) / 2
    }

    /// Whether the newcomer's place is settled.
    public var isPlaced: Bool {
        candidates.lowerBound == candidates.upperBound
    }

    /// Where the newcomer goes in the best-first list (0 is the top), once placed.
    public var position: Int? {
        isPlaced ? candidates.lowerBound : nil
    }

    /// How many questions have been answered (and not taken back).
    public var comparisonsMade: Int {
        history.count
    }

    /// The most questions still to come, for a "two more at most" hint.
    public var remainingComparisonsAtMost: Int {
        Self.maximumComparisons(forCount: candidates.upperBound - candidates.lowerBound)
    }

    /// Whether there is an answer to take back.
    public var canUndo: Bool {
        !history.isEmpty
    }

    /// Records the answer to the current question. Ignored once placed.
    public mutating func record(_ verdict: Verdict) {
        guard let index = comparisonIndex else { return }
        history.append(candidates)
        switch verdict {
        case .better:
            // Better than the item at `index`: it lands at `index` or above.
            candidates = candidates.lowerBound ... index
        case .worse:
            // Worse: it lands below the item at `index`.
            candidates = (index + 1) ... candidates.upperBound
        }
    }

    /// Takes back the last answer, so its question is asked again.
    public mutating func undo() {
        guard let previous = history.popLast() else { return }
        candidates = previous
    }
}
