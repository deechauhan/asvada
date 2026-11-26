import Foundation
import Geo
import Model

/// How many entries a month held, for the stats chart.
struct MonthCount: Identifiable, Equatable {
    /// The first day of the month.
    let start: Date
    let count: Int

    var id: Date {
        start
    }
}

/// The best thing in one country, for "top cafés per country".
struct CountryLeader: Identifiable, Equatable {
    let countryName: String
    let itemName: String

    var id: String {
        countryName
    }
}

/// One drawer's stats: how much it holds and its standout.
struct CollectionStats: Identifiable {
    let collection: ExperienceCollection
    let items: Int
    let entries: Int
    /// The drawer's standout, in its own terms: "No. 1 Prufrock", "Most flown: British Airways
    /// ×2", "Best rated: Lisbon", "23 of 195 countries". Nil when it's empty.
    let standout: String?
    /// For ranked drawers: the best in each country, most-visited countries first (at most five).
    let leadersByCountry: [CountryLeader]

    var id: UUID {
        collection.id
    }
}

/// Look back (#68): stats for everything and for each drawer, worked out from the store.
struct LookBackStats {
    let entries: Int
    let items: Int
    /// Countries stamped, and their share of the world.
    let countries: Int
    let worldShare: Double
    /// The last twelve months, oldest first, this month last.
    let months: [MonthCount]
    /// The thing savoured most often, and how often.
    let favourite: (name: String, count: Int)?
    let drawers: [CollectionStats]

    /// The most countries a ranked drawer's leaders list.
    static let leaderLimit = 5

    init(
        collections: [ExperienceCollection],
        now: Date = .now,
        calendar: Calendar = .current,
        catalog: CountryCatalog = .shared,
    ) {
        let shown = collections.filter { !$0.isHidden }
        let allItems = shown.flatMap { $0.items ?? [] }
        let allEntries = allItems.flatMap { $0.entries ?? [] }
        entries = allEntries.count
        items = allItems.count
        let stamped = Set(shown.filter { $0.kind == .countries }
            .flatMap { $0.items ?? [] }
            .compactMap { $0.countryCode?.uppercased() })
        let progress = ChecklistProgress(stamped: stamped, catalog: catalog)
        countries = progress.stamped
        worldShare = progress.fraction
        months = Self.months(of: allEntries, now: now, calendar: calendar)
        favourite = allItems
            .filter { ($0.entries?.count ?? 0) > 1 }
            .max { lhs, rhs in
                let left = lhs.entries?.count ?? 0
                let right = rhs.entries?.count ?? 0
                return left != right ? left < right : lhs.name > rhs.name
            }
            .map { ($0.name, $0.entries?.count ?? 0) }
        drawers = shown.map { Self.stats(for: $0, catalog: catalog) }
    }

    /// Entries per month for the twelve months up to `now`'s, oldest first.
    static func months(of entries: [Entry], now: Date, calendar: Calendar) -> [MonthCount] {
        guard let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return [] }
        let starts = (0 ..< 12).reversed().compactMap { calendar.date(byAdding: .month, value: -$0, to: thisMonth) }
        return starts.map { start in
            let count = entries.count { calendar.isDate($0.date, equalTo: start, toGranularity: .month) }
            return MonthCount(start: start, count: count)
        }
    }

    static func stats(for collection: ExperienceCollection, catalog: CountryCatalog) -> CollectionStats {
        let items = collection.items ?? []
        let ordered = ExperienceCollection.drawerOrder(items, mode: collection.ratingMode)
        let entryCount = items.reduce(0) { $0 + ($1.entries?.count ?? 0) }
        return CollectionStats(
            collection: collection,
            items: items.count,
            entries: entryCount,
            standout: standout(of: collection, ordered: ordered, catalog: catalog),
            leadersByCountry: collection.ratingMode == .ranked ? leaders(in: ordered, catalog: catalog) : [],
        )
    }

    private static func standout(of collection: ExperienceCollection, ordered: [Item], catalog: CountryCatalog) -> String? {
        guard !ordered.isEmpty else { return nil }
        switch collection.ratingMode {
        case .ranked:
            return ordered.first.map { "No. 1 \($0.name)" }
        case .log:
            guard let most = ordered.max(by: { ($0.entries?.count ?? 0) < ($1.entries?.count ?? 0) }) else { return nil }
            let count = most.entries?.count ?? 0
            let verb = collection.kind == .airlines ? "Most flown" : collection.kind == .films ? "Most watched" : "Most often"
            return count > 1 ? "\(verb): \(most.name) ×\(count)" : "Latest: \(ordered[0].name)"
        case .checklist:
            guard collection.kind == .countries else {
                return ordered.count == 1 ? "1 ticked off" : "\(ordered.count) ticked off"
            }
            let progress = ChecklistProgress(stamped: Set(ordered.compactMap { $0.countryCode?.uppercased() }), catalog: catalog)
            return "\(progress.stamped) of \(progress.total) countries"
        case .stars:
            let rated = ordered.filter { $0.averageRating != nil }
            guard let best = rated.max(by: { ($0.averageRating ?? 0) < ($1.averageRating ?? 0) }) else {
                return "Latest: \(ordered[0].name)"
            }
            return "Best rated: \(best.name)"
        }
    }

    /// The best (first in `ordered`) item in each country, countries with the most items first.
    static func leaders(in ordered: [Item], catalog: CountryCatalog) -> [CountryLeader] {
        var counts: [String: Int] = [:]
        var best: [String: Item] = [:]
        for item in ordered {
            guard let code = item.countryCode?.uppercased() else { continue }
            counts[code, default: 0] += 1
            if best[code] == nil {
                best[code] = item
            }
        }
        return counts.keys
            .sorted { lhs, rhs in
                let left = counts[lhs] ?? 0
                let right = counts[rhs] ?? 0
                return left != right ? left > right : lhs < rhs
            }
            .prefix(leaderLimit)
            .compactMap { code in
                guard let item = best[code], let country = catalog.country(code: code) else { return nil }
                return CountryLeader(countryName: country.name, itemName: item.name)
            }
    }

    /// What VoiceOver says for the months chart: the busiest month, and the year's total.
    static func chartSummary(_ months: [MonthCount]) -> String {
        let total = months.reduce(0) { $0 + $1.count }
        guard total > 0, let busiest = months.max(by: { $0.count < $1.count }) else {
            return "Nothing savoured in the last twelve months"
        }
        let month = busiest.start.formatted(.dateTime.month(.wide).year())
        return "\(total) in the last twelve months. The busiest was \(month), with \(busiest.count)."
    }
}
