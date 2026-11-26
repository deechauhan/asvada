import Foundation
import Geo
import Model
import SwiftData

/// Which suggested visits have been dealt with, so a scan doesn't suggest them again (#65): a
/// visit added to the keepsakes or dismissed. Kept in the app's own settings, by the visit's id
/// (its first photo's), and never leaves the phone.
public struct VisitDecisions {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "photoVisits.handled") {
        self.defaults = defaults
        self.key = key
    }

    /// The ids of visits added or dismissed.
    public var handled: Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    /// Remembers that `id` has been dealt with.
    public func markHandled(_ id: String) {
        defaults.set(Array(handled.union([id])).sorted(), forKey: key)
    }

    /// Forgets every decision, so dismissed visits are suggested again.
    public func reset() {
        defaults.removeObject(forKey: key)
    }
}

public extension Repository {
    /// The visits worth suggesting: not already dealt with, in a country (the only place a photo
    /// scan can name), and not already in the keepsakes (that country already has an entry within
    /// a day of the visit's dates). Earliest first.
    func pendingVisits(
        from visits: [VisitCluster],
        handled: Set<String>,
        calendar: Calendar = .current,
    ) -> [VisitCluster] {
        visits.filter { visit in
            guard !handled.contains(visit.id), let code = visit.countryCode else { return false }
            return !hasEntry(inCountry: code, near: visit, calendar: calendar)
        }
    }

    /// Adds a suggested visit to the keepsakes: the country is stamped in Countries (once, however
    /// many visits), with an entry on the day the visit started, and the visit becomes a trip of
    /// that country's name over its dates, holding that entry.
    ///
    /// - Returns: the visit's entry, or nil if the visit has no country, or there's no Countries
    ///   collection (nothing is added then).
    @discardableResult
    func acceptVisit(_ visit: VisitCluster, calendar: Calendar = .current) throws -> Entry? {
        guard
            let code = visit.countryCode,
            let country = CountryCatalog.shared.country(code: code),
            let countries = try collections(includeHidden: true).first(where: { $0.kind == .countries })
        else { return nil }
        let stamp = upsertItem(named: country.name, externalRef: "iso:\(country.code)", in: countries)
        stamp.countryCode = country.code
        let entry = (stamp.entries ?? []).first { calendar.isDate($0.date, inSameDayAs: visit.start) }
            ?? addEntry(to: stamp, date: visit.start)
        let trip = Trip(name: country.name, start: visit.start, end: max(visit.start, visit.end))
        context.insert(trip)
        entry.trip = trip
        try save()
        return entry
    }

    private func hasEntry(inCountry code: String, near visit: VisitCluster, calendar: Calendar) -> Bool {
        let items = (try? context.fetch(FetchDescriptor<Item>())) ?? []
        guard
            let windowStart = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: visit.start)),
            let windowEnd = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: visit.end))
        else { return false }
        return items.contains { item in
            item.countryCode?.uppercased() == code.uppercased()
                && (item.entries ?? []).contains { $0.date >= windowStart && $0.date < windowEnd }
        }
    }
}
