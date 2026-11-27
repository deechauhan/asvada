import Foundation
import Model

/// One course of the Tasting Menu: its place in the meal, what was served, and a line about it.
struct Course: Identifiable, Equatable {
    /// "Amuse-bouche", "Entrée"…
    let title: String
    /// What it was: "Prufrock Coffee", "Japan, Peru".
    let dish: String
    /// A line under it: "your first coffee, 3 January".
    let note: String

    var id: String {
        title
    }
}

/// Year in review (#70): the year set as a printed degustation menu (CONCEPT.md ⑥). The
/// amuse-bouche is the year's first coffee, the entrée its new countries, the main its best
/// restaurant, dessert its film and the digestif its most-flown airline. A course with nothing to
/// serve is left off the menu.
struct TastingMenu: Equatable {
    let year: Int
    let courses: [Course]
    /// How many things were savoured that year.
    let total: Int

    var isEmpty: Bool {
        courses.isEmpty
    }

    init(year: Int, collections: [ExperienceCollection], calendar: Calendar = .current) {
        self.year = year
        let pantry = Pantry(year: year, collections: collections.filter { !$0.isHidden }, calendar: calendar)
        total = pantry.total
        courses = [
            pantry.amuseBouche(),
            pantry.entree(),
            pantry.main(),
            pantry.dessert(),
            pantry.digestif(),
        ].compactMap(\.self)
    }

    /// The year to show first: this one, or last year early in January before anything's logged.
    static func defaultYear(collections: [ExperienceCollection], now: Date = .now, calendar: Calendar = .current) -> Int {
        let thisYear = calendar.component(.year, from: now)
        let hasThisYear = collections.flatMap { $0.items ?? [] }.flatMap { $0.entries ?? [] }
            .contains { calendar.component(.year, from: $0.date) == thisYear }
        return hasThisYear ? thisYear : thisYear - 1
    }

    /// The years with anything savoured, newest first.
    static func years(collections: [ExperienceCollection], calendar: Calendar = .current) -> [Int] {
        let years = collections.flatMap { $0.items ?? [] }.flatMap { $0.entries ?? [] }.map { calendar.component(
            .year,
            from: $0.date,
        ) }
        return Array(Set(years)).sorted(by: >)
    }
}

/// What a year holds, for setting its menu: each drawer's things savoured that year.
private struct Pantry {
    let year: Int
    let collections: [ExperienceCollection]
    let calendar: Calendar

    /// How many things were savoured that year.
    var total: Int {
        collections.flatMap { $0.items ?? [] }.reduce(0) { $0 + entries(of: $1).count }
    }

    func entries(of item: Item) -> [Entry] {
        (item.entries ?? []).filter { calendar.component(.year, from: $0.date) == year }
    }

    func items(_ kind: CollectionKind) -> [Item] {
        collections.filter { $0.kind == kind }.flatMap { $0.items ?? [] }.filter { !entries(of: $0).isEmpty }
    }

    /// The year's first coffee.
    func amuseBouche() -> Course? {
        let coffees = items(.cafes).compactMap { item in entries(of: item).map(\.date).min().map { (item, $0) } }
        guard let first = coffees.min(by: { $0.1 < $1.1 }) else { return nil }
        return Course(
            title: "Amuse-bouche",
            dish: first.0.name,
            note: "your first coffee, \(first.1.formatted(.dateTime.day().month(.wide)))",
        )
    }

    /// Countries stamped for the first time that year, in the order they were.
    func entree() -> Course? {
        func firstVisit(_ item: Item) -> Date {
            item.entries?.map(\.date).min() ?? .distantFuture
        }
        let countries = collections.filter { $0.kind == .countries }.flatMap { $0.items ?? [] }
            .filter { calendar.component(.year, from: firstVisit($0)) == year }
            .sorted { firstVisit($0) < firstVisit($1) }
        guard !countries.isEmpty else { return nil }
        return Course(
            title: "Entrée",
            dish: countries.prefix(4).map(\.name).formatted(.list(type: .and)),
            note: countries.count == 1 ? "a new country" : "\(countries.count) new countries",
        )
    }

    /// The best restaurant visited that year.
    func main() -> Course? {
        ExperienceCollection.drawerOrder(items(.restaurants), mode: .ranked).first
            .map { Course(title: "Main", dish: $0.name, note: "the best meal of the year") }
    }

    /// The film of the year: how it landed, then how often.
    func dessert() -> Course? {
        func score(_ film: Item) -> (Double, Int) {
            (entries(of: film).compactMap(\.rating).max() ?? 0, entries(of: film).count)
        }
        let films = items(.films).sorted { lhs, rhs in
            score(lhs) != score(rhs) ? score(lhs) > score(rhs) : lhs.name < rhs.name
        }
        guard let film = films.first else { return nil }
        let count = entries(of: film).count
        return Course(
            title: "Dessert",
            dish: film.name,
            note: count > 1 ? "the film of the year, seen \(count) times" : "the film of the year",
        )
    }

    /// The airline flown most that year.
    func digestif() -> Course? {
        let airlines = items(.airlines).sorted { lhs, rhs in
            let left = entries(of: lhs).count
            let right = entries(of: rhs).count
            return left != right ? left > right : lhs.name < rhs.name
        }
        guard let airline = airlines.first else { return nil }
        let flights = entries(of: airline).count
        return Course(title: "Digestif", dish: airline.name, note: flights == 1 ? "1 flight" : "\(flights) flights")
    }
}
