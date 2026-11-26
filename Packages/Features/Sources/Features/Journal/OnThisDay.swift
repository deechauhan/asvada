import Foundation
import Model

/// Something savoured on this day in an earlier year.
struct Anniversary: Identifiable {
    let entry: Entry
    let item: Item
    /// How many years ago: 1 for a year ago.
    let yearsAgo: Int

    var id: UUID {
        entry.id
    }
}

/// On this day (#69): what was savoured on today's date in earlier years, for the Journal's
/// face-down card, the saffron tab on a drawer and the morning reminder.
enum OnThisDay {
    /// The entries (and their items) from `day`'s month and day in earlier years, most recent
    /// year first, then A to Z. On 28 February in a year with no 29th, the 29th's count too.
    static func anniversaries(in entries: [Entry], on day: Date, calendar: Calendar = .current) -> [Anniversary] {
        let today = calendar.dateComponents([.year, .month, .day], from: day)
        guard let year = today.year, let month = today.month, let date = today.day else { return [] }
        let leapDayToo = month == 2 && date == 28 && !isLeapYear(year, calendar: calendar)
        return entries.compactMap { entry -> Anniversary? in
            guard let item = entry.item, item.collection != nil else { return nil }
            let then = calendar.dateComponents([.year, .month, .day], from: entry.date)
            guard
                let thenYear = then.year, thenYear < year, then.month == month,
                then.day == date || (leapDayToo && then.day == 29)
            else { return nil }
            return Anniversary(entry: entry, item: item, yearsAgo: year - thenYear)
        }
        .sorted { lhs, rhs in
            lhs.yearsAgo != rhs.yearsAgo
                ? lhs.yearsAgo < rhs.yearsAgo
                : lhs.item.name.localizedStandardCompare(rhs.item.name) == .orderedAscending
        }
    }

    /// "A year ago, you savoured Perfect Days." "3 years ago, you savoured Lisbon and 2 more."
    static func headline(_ anniversaries: [Anniversary]) -> String? {
        guard let first = anniversaries.first else { return nil }
        let when = first.yearsAgo == 1 ? "A year ago" : "\(first.yearsAgo) years ago"
        let sameYear = anniversaries.filter { $0.yearsAgo == first.yearsAgo }
        let others = anniversaries.count - 1
        if others == 0 {
            return "\(when), you savoured \(first.item.name)."
        }
        if sameYear.count == anniversaries.count {
            return "\(when), you savoured \(first.item.name) and \(others) more."
        }
        return "On this day, you savoured \(first.item.name) and \(others) more."
    }

    /// The years-ago line on one anniversary: "1 year ago", "4 years ago".
    static func ago(_ years: Int) -> String {
        years == 1 ? "1 year ago" : "\(years) years ago"
    }

    private static func isLeapYear(_ year: Int, calendar: Calendar) -> Bool {
        guard let feb = calendar.date(from: DateComponents(year: year, month: 2, day: 1)),
              let days = calendar.range(of: .day, in: .month, for: feb)
        else { return false }
        return days.count == 29
    }
}

extension ExperienceCollection {
    /// What in this drawer was savoured on `day`'s date in earlier years.
    func anniversaries(on day: Date = .now, calendar: Calendar = .current) -> [Anniversary] {
        OnThisDay.anniversaries(in: (items ?? []).flatMap { $0.entries ?? [] }, on: day, calendar: calendar)
    }
}
