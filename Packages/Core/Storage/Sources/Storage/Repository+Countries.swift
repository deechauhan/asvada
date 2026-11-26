import Foundation
import Geo
import Model
import SwiftData

public extension Repository {
    /// Marks the country a place is in as visited: logging a café in Lisbon stamps Portugal.
    ///
    /// The country comes from the item's `countryCode` if it has one, otherwise from its
    /// coordinates, looked up offline in the bundled outlines (a point just off the coast counts
    /// as that coast's country). The item keeps the code it was given. The country is added to
    /// the Countries collection once, and gets at most one entry per day, so its passport stamp
    /// shows the first visit. Items in Countries itself, items without a place and places at sea
    /// stamp nothing.
    ///
    /// - Returns: the country's item in Countries, or nil if nothing was stamped.
    @discardableResult
    func stampCountry(of item: Item, on date: Date = .now) -> Item? {
        guard item.collection?.kind != .countries, let code = countryCode(of: item) else { return nil }
        item.countryCode = code
        guard
            let country = CountryCatalog.shared.country(code: code),
            let countries = countriesCollection()
        else { return nil }
        let stamp = upsertItem(named: country.name, externalRef: "iso:\(country.code)", in: countries)
        stamp.countryCode = country.code
        let calendar = Calendar.current
        let alreadyThatDay = stamp.entries?.contains { calendar.isDate($0.date, inSameDayAs: date) } ?? false
        if !alreadyThatDay {
            let entry = Entry(date: date)
            context.insert(entry)
            entry.item = stamp
        }
        return stamp
    }

    /// The ISO codes stamped in a checklist collection such as Countries.
    func stampedCodes(in collection: ExperienceCollection) -> Set<String> {
        Set((collection.items ?? []).compactMap { $0.countryCode?.uppercased() })
    }

    /// Makes `collection`'s stamps exactly `codes`: stamps each missing country once (keyed by ISO
    /// code, as onboarding does) and washes off the rest, with their own dated stamps. Places that
    /// stamped a country (a café in Lisbon) keep their entries in their own collections.
    func setStamped(_ codes: Set<String>, in collection: ExperienceCollection) throws {
        let wanted = Set(codes.map { $0.uppercased() })
        let have = stampedCodes(in: collection)
        for code in wanted.subtracting(have).sorted() {
            guard let country = CountryCatalog.shared.country(code: code) else { continue }
            let item = upsertItem(named: country.name, externalRef: "iso:\(country.code)", in: collection)
            item.countryCode = country.code
        }
        for item in collection.items ?? [] {
            guard let code = item.countryCode?.uppercased(), !wanted.contains(code) else { continue }
            item.collection = nil
            context.delete(item)
        }
        try save()
    }

    /// The ISO code for where `item` is: its own code, or a lookup from its coordinates.
    private func countryCode(of item: Item) -> String? {
        if let code = item.countryCode, !code.isEmpty {
            return code.uppercased()
        }
        guard let latitude = item.latitude, let longitude = item.longitude else { return nil }
        return CountryCatalog.shared.country(at: GeoPoint(longitude: longitude, latitude: latitude))?.code
    }

    private func countriesCollection() -> ExperienceCollection? {
        let collections = (try? context.fetch(FetchDescriptor<ExperienceCollection>())) ?? []
        return collections.first { $0.kind == .countries }
    }
}
