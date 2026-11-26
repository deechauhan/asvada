import DesignSystem
import Foundation
import Model

/// The numbers at the top of an item's page: how often, how it landed, where it ranks.
struct ItemStats: Equatable {
    /// How many times it's been savoured.
    let count: Int
    /// "3 visits", "2 flights", "Watched twice"…
    let countLine: String
    /// The average rating's relish word with its number ("Lovely · 4.2"), for star collections.
    let relish: String?
    /// "No. 2 in Cafés", for ranked collections with the item placed.
    let rankLine: String?

    /// - Parameter rank: the item's place in its collection's ranking (0 is the top), if placed.
    init(item: Item, collection: ExperienceCollection, rank: Int?) {
        let entries = item.entries ?? []
        count = entries.count
        countLine = Self.countLine(entries.count, kind: collection.kind)
        let ratings = entries.compactMap(\.rating)
        if collection.ratingMode.ratesEntries, !ratings.isEmpty {
            let average = ratings.reduce(0, +) / Double(ratings.count)
            let word = Relish.word(for: average) ?? ""
            relish = "\(word) · \(average.formatted(.number.precision(.fractionLength(1))))"
        } else {
            relish = nil
        }
        rankLine = collection.ratingMode == .ranked ? rank.map { "No. \($0 + 1) in \(collection.name)" } : nil
    }

    /// "1 visit", "3 flights", "Watched twice", or the ghost line for none (never a bare "0").
    static func countLine(_ count: Int, kind: CollectionKind) -> String {
        guard count >= 1 else { return "Not savoured yet" }
        switch kind {
        case .films:
            switch count {
            case 1: return "Watched once"
            case 2: return "Watched twice"
            default: return "Watched \(count) times"
            }
        case .airlines:
            return count == 1 ? "1 flight" : "\(count) flights"
        case .countries, .cities, .cafes, .restaurants, .custom:
            return count == 1 ? "1 visit" : "\(count) visits"
        }
    }
}

extension Item {
    /// Its entries, newest first.
    var entriesNewestFirst: [Entry] {
        (entries ?? []).sorted { $0.date > $1.date }
    }

    /// The thumbnail of its newest photo (newest entry first, then newest taken), for cards that
    /// show the thing itself, such as the duel's.
    var latestThumbnailData: Data? {
        for entry in entriesNewestFirst {
            let photos = (entry.photos ?? []).filter { $0.thumbnailData != nil }
            if let newest = photos.max(by: { ($0.takenAt ?? .distantPast) < ($1.takenAt ?? .distantPast) }) {
                return newest.thumbnailData
            }
        }
        return nil
    }
}

extension RatingMode {
    /// Whether each entry can say how it landed on the relish scale: always for stars, and
    /// optionally for logs (a rewatch or a flight can be rated too, #39).
    var ratesEntries: Bool {
        self == .stars || self == .log
    }
}
