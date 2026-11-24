import Testing
@testable import Ranking

/// A small seeded generator (SplitMix64), so the property tests explore many cases but always the
/// same ones: a failure reproduces exactly.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

/// Runs a full insertion against an oracle that knows the newcomer belongs at `truth`.
func place(count: Int, truth: Int) -> BinaryInsertion {
    var insertion = BinaryInsertion(count: count)
    while let index = insertion.comparisonIndex {
        // Items above `truth` are better than the newcomer; the newcomer beats the rest.
        insertion.record(index < truth ? .worse : .better)
    }
    return insertion
}
