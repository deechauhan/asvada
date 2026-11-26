import Foundation
import Geo
import Model

/// The four overviews of an open drawer (INTERACTION.md §4b step 6, #44), one per rating mode.
enum SpreadKind: Equatable {
    /// Ranked: a printed list best-first, No. 1 as the hero.
    case menu
    /// Log: stubs and passes by year.
    case ticketBox
    /// Checklist: pages of stamps.
    case passport
    /// Stars and custom: tilted keepsakes in a loose grid.
    case pinboard

    init(mode: RatingMode) {
        switch mode {
        case .ranked: self = .menu
        case .log: self = .ticketBox
        case .checklist: self = .passport
        case .stars: self = .pinboard
        }
    }

    /// The spread's name, as its masthead.
    var title: String {
        switch self {
        case .menu: "The Menu"
        case .ticketBox: "Ticket box"
        case .passport: "Passport"
        case .pinboard: "Pinboard"
        }
    }
}

/// How a spread is sorted and filtered: by date, rating or name (or rank, in The Menu), and to
/// one year or one country. Chosen in the spread's toolbar; not saved.
struct SpreadOptions: Equatable {
    enum Sort: String, CaseIterable, Identifiable {
        /// The drawer's own order: best first when ranked, otherwise newest first.
        case drawer
        case newest
        case rating
        case name

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .drawer: "Drawer order"
            case .newest: "Newest first"
            case .rating: "Best rated"
            case .name: "A to Z"
            }
        }
    }

    var sort = Sort.drawer
    /// Only things last savoured in this year.
    var year: Int?
    /// Only things in this country (ISO code).
    var country: String?

    var isFiltered: Bool {
        year != nil || country != nil
    }

    /// `items` filtered and sorted. `mode` decides the drawer order.
    func apply(to items: [Item], mode: RatingMode, calendar: Calendar = .current) -> [Item] {
        let kept = items.filter { item in
            (year == nil || calendar.component(.year, from: item.lastEncountered) == year)
                && (country == nil || item.countryCode?.uppercased() == country)
        }
        switch sort {
        case .drawer:
            return ExperienceCollection.drawerOrder(kept, mode: mode)
        case .newest:
            return ExperienceCollection.drawerOrder(kept, mode: .log)
        case .rating:
            return kept.sorted { lhs, rhs in
                let left = lhs.averageRating ?? -1
                let right = rhs.averageRating ?? -1
                return left != right ? left > right : lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        case .name:
            return kept.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    /// The years anything in `items` was last savoured, newest first: the year filter's choices.
    static func years(in items: [Item], calendar: Calendar = .current) -> [Int] {
        Array(Set(items.map { calendar.component(.year, from: $0.lastEncountered) })).sorted(by: >)
    }

    /// The countries `items` are in, by name: the country filter's choices.
    static func countries(in items: [Item], catalog: CountryCatalog = .shared) -> [Country] {
        let codes = Set(items.compactMap { $0.countryCode?.uppercased() })
        return codes.compactMap { catalog.country(code: $0) }.sorted { $0.name < $1.name }
    }
}

extension Item {
    /// The average of its entries' ratings, or nil when none is rated.
    var averageRating: Double? {
        let ratings = (entries ?? []).compactMap(\.rating)
        guard !ratings.isEmpty else { return nil }
        return ratings.reduce(0, +) / Double(ratings.count)
    }
}

/// One year of a ticket box: the year and its keepsakes, newest first.
struct SpreadYear: Identifiable, Equatable {
    let year: Int
    let items: [Item]

    var id: Int {
        year
    }

    static func == (lhs: SpreadYear, rhs: SpreadYear) -> Bool {
        lhs.year == rhs.year && lhs.items.map(\.id) == rhs.items.map(\.id)
    }

    /// `items` (already in order) split into years, keeping their order.
    static func group(_ items: [Item], calendar: Calendar = .current) -> [SpreadYear] {
        var years: [SpreadYear] = []
        for item in items {
            let year = calendar.component(.year, from: item.lastEncountered)
            if let last = years.last, last.year == year {
                years[years.count - 1] = SpreadYear(year: year, items: last.items + [item])
            } else {
                years.append(SpreadYear(year: year, items: [item]))
            }
        }
        return years
    }
}
