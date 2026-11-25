import Foundation
import Model

/// The savour step quick-log asks for after you've said what it was, by the collection's rating
/// mode (INTERACTION.md §5, step 8).
enum SavourStep: Equatable {
    /// Ranked and new: "Which did you savour more?" against the `count` items already ranked.
    /// With none ranked yet it's straight to No. 1.
    case duel(count: Int)
    /// Ranked and already placed: "Still No. n?", skipping the duel.
    case still(rank: Int)
    /// Stars: five ā marks.
    case relish
    /// Log: when was it?
    case when
    /// Checklist: stamp it.
    case stamp
}

/// "When?" for logs: today, yesterday or about a week ago.
enum LogWhen: CaseIterable, Identifiable {
    case today
    case yesterday
    case lastWeek

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .lastWeek: "Last week"
        }
    }

    /// The date it stands for, counted back from `now`.
    func date(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .today: now
        case .yesterday: calendar.date(byAdding: .day, value: -1, to: now) ?? now
        case .lastWeek: calendar.date(byAdding: .day, value: -7, to: now) ?? now
        }
    }
}

/// Quick-log's decisions and words, kept out of the views so they're unit-tested.
enum QuickLogFlow {
    static let duelQuestion = "Which did you savour more?"

    /// The savour step for an item: `rank` is its place in the ranking (0 is the top) if it has
    /// one, and `othersRanked` how many other items are ranked.
    static func step(for mode: RatingMode, rank: Int?, othersRanked: Int) -> SavourStep {
        switch mode {
        case .ranked:
            if let rank {
                return .still(rank: rank + 1)
            }
            return .duel(count: othersRanked)
        case .stars: return .relish
        case .log: return .when
        case .checklist: return .stamp
        }
    }

    /// "That makes it ×3" once something has been logged before; nil the first time.
    static func timesLabel(previousEntries: Int) -> String? {
        guard previousEntries >= 1 else { return nil }
        return "That makes it ×\(previousEntries + 1)"
    }

    /// The toast after sealing: "Savoured in 6.4 s · it's in your Cafés drawer".
    static func toast(seconds: TimeInterval, collection: String) -> String {
        let shown = (max(seconds, 0) * 10).rounded() / 10
        return "Savoured in \(shown.formatted(.number.precision(.fractionLength(1)))) s · it's in your \(collection) drawer"
    }

    /// Items in the drawer matching `query` (any part of the name, ignoring case and accents),
    /// the most recently savoured first; everything when the query is empty.
    static func matches(_ items: [Item], query: String) -> [Item] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let found = needle.isEmpty
            ? items
            : items.filter { $0.name.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        return found.sorted { lastSavoured($0) > lastSavoured($1) }
    }

    /// Whether `query` names an item already in the list (so "Add …" isn't offered twice).
    static func hasExactMatch(_ items: [Item], query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.contains { $0.name.compare(needle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    private static func lastSavoured(_ item: Item) -> Date {
        item.entries?.map(\.date).max() ?? item.createdAt
    }
}
