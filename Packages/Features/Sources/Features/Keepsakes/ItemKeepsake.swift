import DesignSystem
import Foundation
import Model
import SwiftUI

extension CollectionKind {
    /// The keepsake template for this kind of collection. Custom collections use the luggage tag.
    var keepsakeStyle: KeepsakeStyle {
        switch self {
        case .cafes: .receipt
        case .restaurants: .menuCard
        case .countries: .passportStamp
        case .cities: .postcard
        case .airlines: .boardingPass
        case .films: .ticketStub
        case .custom: .luggageTag
        }
    }
}

extension Item {
    /// The most recent entry, if any.
    var latestEntry: Entry? {
        entries?.max { $0.date < $1.date }
    }

    /// How many times this has been savoured (at least once once it's in a collection).
    var encounterCount: Int {
        max(entries?.count ?? 0, 1)
    }

    /// The IATA code for an airline item, from an `iata:XX` external ref or the name's initials.
    var iataCode: String {
        if let externalRef, externalRef.hasPrefix("iata:") {
            return String(externalRef.dropFirst(5)).uppercased()
        }
        let initials = name.split(separator: " ").compactMap(\.first).prefix(2)
        return String(initials).uppercased()
    }

    /// Up to three dishes from the latest note: comma- or line-separated phrases.
    var dishes: [String] {
        let note = latestEntry?.notes ?? ""
        let phrases = note
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(phrases.prefix(3))
    }
}

/// An item drawn as its collection's keepsake: receipt, menu card, passport stamp, postcard,
/// boarding pass, ticket stub or luggage tag.
struct ItemKeepsake: View {
    let item: Item
    let collection: ExperienceCollection
    /// Position in a ranked collection (1 = best), if ranked.
    var rank: Int?

    private var ink: ColorToken {
        collection.accent.token
    }

    private var date: Date? {
        item.latestEntry?.date
    }

    private var relish: String? {
        Relish.word(for: item.latestEntry?.rating)
    }

    var body: some View {
        switch collection.kind.keepsakeStyle {
        case .receipt:
            Receipt(name: item.name, date: date, visits: item.encounterCount, rank: rank, ink: ink)
        case .menuCard:
            MenuCard(name: item.name, dishes: item.dishes, date: date, rank: rank, ink: ink)
        case .passportStamp:
            PassportStamp(country: item.name, code: item.isoCode, date: item.firstEncountered, ink: ink)
        case .postcard:
            Postcard(city: item.name, country: item.countryCode, date: date, relish: relish, ink: ink)
        case .boardingPass:
            BoardingPass(
                airline: item.name,
                code: item.iataCode,
                date: date,
                flights: item.encounterCount,
                barcodeSeed: item.id.uuidString,
                ink: ink,
            )
        case .ticketStub:
            TicketStub(title: item.name, date: date, relish: relish, rewatches: item.encounterCount, ink: ink)
        case .luggageTag:
            LuggageTag(
                collection: collection.name,
                title: item.name,
                detail: date.map(KeepsakeDate.short),
                icon: collection.icon,
                ink: ink,
            )
        }
    }
}
