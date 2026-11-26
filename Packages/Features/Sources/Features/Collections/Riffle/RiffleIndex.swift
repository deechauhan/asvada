import DesignSystem
import Foundation
import Model

/// One card standing in an open drawer: a keepsake, or a guide card that heads a group (a year
/// in a log, a relish word in a starred drawer).
struct RiffleCard: Identifiable {
    enum Content {
        case keepsake(Item, rank: Int?)
        /// A plum-wash divider: "2025 · 3 in this year", "Unforgettable · 2 keepsakes".
        case guide(title: String, detail: String)
    }

    let id: String
    let content: Content
    /// What its index tab says: "No. 3", "2025", "Lisbon".
    let tab: String
    /// What VoiceOver reads for it.
    let spoken: String

    var item: Item? {
        if case let .keepsake(item, _) = content {
            return item
        }
        return nil
    }

    var isGuide: Bool {
        item == nil
    }
}

/// A label on the right-hand jump rail and the card it jumps to.
struct RiffleMark: Identifiable, Equatable {
    let label: String
    let cardIndex: Int

    var id: Int {
        cardIndex
    }
}

/// The order of a drawer's cards, their index tabs and the jump rail (INTERACTION.md §4b), by
/// rating mode:
/// - **ranked:** best first, tabs "No. n";
/// - **log:** newest first, with a guide card per year;
/// - **stars and custom:** grouped by relish word, best first, with a guide card per group;
/// - **checklist:** newest stamp first, with the rail by initial.
struct RiffleIndex {
    let cards: [RiffleCard]
    let marks: [RiffleMark]

    /// The most labels the rail shows; longer drawers show every few.
    static let maximumMarks = 12
    /// What unrated keepsakes are grouped under in a starred drawer.
    static let unrated = "Not yet relished"

    /// Where a card's tab sits along its top edge: left, middle or right third, in turn.
    static func tabSlot(for index: Int) -> Int {
        index % 3
    }

    /// The card index of `item` (its keepsake card), if it's in the drawer.
    func index(of item: Item) -> Int? {
        cards.firstIndex { $0.item?.id == item.id }
    }

    static func make(items: [Item], mode: RatingMode, calendar: Calendar = .current) -> RiffleIndex {
        let ordered = ExperienceCollection.drawerOrder(items, mode: mode)
        switch mode {
        case .ranked: return ranked(ordered)
        case .log: return log(ordered, calendar: calendar)
        case .stars: return relished(ordered)
        case .checklist: return checklist(ordered)
        }
    }

    // MARK: - Per mode

    private static func ranked(_ items: [Item]) -> RiffleIndex {
        let cards = items.enumerated().map { index, item in
            RiffleCard(
                id: item.id.uuidString,
                content: .keepsake(item, rank: index + 1),
                tab: "No. \(index + 1)",
                spoken: "No. \(index + 1), \(item.name)",
            )
        }
        let marks = cards.indices.map { RiffleMark(label: "No. \($0 + 1)", cardIndex: $0) }
        return RiffleIndex(cards: cards, marks: thinned(marks))
    }

    private static func log(_ items: [Item], calendar: Calendar) -> RiffleIndex {
        let groups = grouped(items) { String(calendar.component(.year, from: $0.lastEncountered)) }
        var cards: [RiffleCard] = []
        var marks: [RiffleMark] = []
        for (year, members) in groups {
            marks.append(RiffleMark(label: year, cardIndex: cards.count))
            let detail = "\(members.count) in this year"
            cards.append(RiffleCard(
                id: "year-\(year)",
                content: .guide(title: year, detail: detail),
                tab: year,
                spoken: "\(year), \(detail)",
            ))
            for item in members {
                let times = item.encounterCount > 1 ? " ×\(item.encounterCount)" : ""
                cards.append(RiffleCard(
                    id: item.id.uuidString,
                    content: .keepsake(item, rank: nil),
                    tab: KeepsakeDate.short(item.lastEncountered) + times,
                    spoken: item.name,
                ))
            }
        }
        return RiffleIndex(cards: cards, marks: thinned(marks))
    }

    private static func relished(_ items: [Item]) -> RiffleIndex {
        let order = Relish.words.reversed() + [unrated]
        let groups = grouped(items) { Relish.word(for: $0.latestEntry?.rating) ?? unrated }
            .sorted { (order.firstIndex(of: $0.key) ?? order.count) < (order.firstIndex(of: $1.key) ?? order.count) }
        var cards: [RiffleCard] = []
        var marks: [RiffleMark] = []
        for (word, members) in groups {
            marks.append(RiffleMark(label: word, cardIndex: cards.count))
            let detail = members.count == 1 ? "1 keepsake" : "\(members.count) keepsakes"
            cards.append(RiffleCard(
                id: "relish-\(word)",
                content: .guide(title: word, detail: detail),
                tab: word,
                spoken: "\(word), \(detail)",
            ))
            for item in members {
                cards.append(RiffleCard(
                    id: item.id.uuidString,
                    content: .keepsake(item, rank: nil),
                    tab: item.name,
                    spoken: "\(word), \(item.name)",
                ))
            }
        }
        return RiffleIndex(cards: cards, marks: thinned(marks))
    }

    private static func checklist(_ items: [Item]) -> RiffleIndex {
        let cards = items.map { item in
            RiffleCard(id: item.id.uuidString, content: .keepsake(item, rank: nil), tab: item.name, spoken: item.name)
        }
        var marks: [RiffleMark] = []
        for (index, card) in cards.enumerated() {
            let initial = card.tab.prefix(1).uppercased()
            if marks.last?.label != initial {
                marks.append(RiffleMark(label: initial, cardIndex: index))
            }
        }
        return RiffleIndex(cards: cards, marks: thinned(marks))
    }

    // MARK: - Helpers

    /// `items` split into runs by `key`, keeping their order; a key seen again later joins its
    /// first run.
    private static func grouped(_ items: [Item], by key: (Item) -> String) -> [(key: String, value: [Item])] {
        var groups: [(key: String, value: [Item])] = []
        for item in items {
            let name = key(item)
            if let index = groups.firstIndex(where: { $0.key == name }) {
                groups[index].value.append(item)
            } else {
                groups.append((name, [item]))
            }
        }
        return groups
    }

    /// At most `maximumMarks` marks, evenly spaced, always keeping the first.
    static func thinned(_ marks: [RiffleMark]) -> [RiffleMark] {
        guard marks.count > maximumMarks else { return marks }
        let step = Int((Double(marks.count) / Double(maximumMarks)).rounded(.up))
        return marks.enumerated().filter { $0.offset.isMultiple(of: step) }.map(\.element)
    }
}
