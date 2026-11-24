import Model
import Ranking

public extension Repository {
    /// The ranked items of a collection, best first. Items not yet placed (no `rankScore`) are
    /// left out; ties break by name so the order is stable.
    func ranking(of collection: ExperienceCollection) -> [Item] {
        let placed = (collection.items ?? []).compactMap { item in item.rankScore.map { (item, $0) } }
        return placed
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                return lhs.0.name.localizedStandardCompare(rhs.0.name) == .orderedAscending
            }
            .map(\.0)
    }

    /// Gives `item` the place `position` (0 is the top) in its collection's ranking, as found by a
    /// `BinaryInsertion` over `ranking(of:)` without the item itself. Usually only the item's score
    /// changes; when its neighbours are too close, the whole ranking is renumbered. An item that
    /// was already ranked moves to the new place.
    func place(_ item: Item, at position: Int, in collection: ExperienceCollection) {
        let others = ranking(of: collection).filter { $0.id != item.id }
        let slot = min(max(position, 0), others.count)
        let placement = RankScores.place(at: slot, among: others.compactMap(\.rankScore))
        if let rebalanced = placement.rebalanced {
            for (other, score) in zip(others, rebalanced) {
                other.rankScore = score
            }
        }
        item.rankScore = placement.score
    }

    /// Takes `item` out of the ranking (it stays in the collection, unranked).
    func unrank(_ item: Item) {
        item.rankScore = nil
    }
}
