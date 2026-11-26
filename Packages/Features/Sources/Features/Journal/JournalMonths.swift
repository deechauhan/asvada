import Foundation
import Model

/// One month of the Journal: its masthead date, a one-line summary, and its entries newest first.
struct JournalMonth: Identifiable {
    /// "2026-11".
    let id: String
    /// The first day of the month, for the masthead.
    let start: Date
    let entries: [Entry]
    /// "4 cafés · 1 country · 2 films".
    let summary: String
}

/// Groups every entry, across all collections, into months for the Journal's feed.
enum JournalMonths {
    /// Entries grouped by calendar month, newest month first and newest entry first within it.
    /// Entries whose item has gone are left out.
    static func group(_ entries: [Entry], calendar: Calendar = .current) -> [JournalMonth] {
        let live = entries.filter { $0.item?.collection != nil }.sorted { $0.date > $1.date }
        var months: [JournalMonth] = []
        var bucket: [Entry] = []
        var bucketKey: String?
        func flush() {
            guard let bucketKey, let first = bucket.first else { return }
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: first.date)) ?? first.date
            months.append(JournalMonth(id: bucketKey, start: start, entries: bucket, summary: summary(of: bucket)))
        }
        for entry in live {
            let parts = calendar.dateComponents([.year, .month], from: entry.date)
            let key = String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
            if key != bucketKey {
                flush()
                bucket = []
                bucketKey = key
            }
            bucket.append(entry)
        }
        flush()
        return months
    }

    /// "4 cafés · 1 country · 2 films": how many entries per collection, the most first.
    static func summary(of entries: [Entry]) -> String {
        var counts: [(collection: ExperienceCollection, count: Int)] = []
        for entry in entries {
            guard let collection = entry.item?.collection else { continue }
            if let index = counts.firstIndex(where: { $0.collection.id == collection.id }) {
                counts[index].count += 1
            } else {
                counts.append((collection, 1))
            }
        }
        return counts
            .sorted { lhs, rhs in
                lhs.count != rhs.count ? lhs.count > rhs.count : lhs.collection.name < rhs.collection.name
            }
            .map { phrase(count: $0.count, collection: $0.collection) }
            .joined(separator: " · ")
    }

    /// "1 café", "3 films", "2 flights"; custom collections read "2 in Concerts".
    static func phrase(count: Int, collection: ExperienceCollection) -> String {
        let one = count == 1
        switch collection.kind {
        case .cafes: return "\(count) \(one ? "café" : "cafés")"
        case .restaurants: return "\(count) \(one ? "restaurant" : "restaurants")"
        case .countries: return "\(count) \(one ? "country" : "countries")"
        case .cities: return "\(count) \(one ? "city" : "cities")"
        case .airlines: return "\(count) \(one ? "flight" : "flights")"
        case .films: return "\(count) \(one ? "film" : "films")"
        case .custom: return "\(count) in \(collection.name)"
        }
    }
}
