import Foundation
import Model

/// What the Atlas shows (#52): everything, or only some collections, years or one trip. An empty
/// filter shows it all; a filter keeps an entry only if it passes every part that's set.
struct AtlasFilter: Equatable {
    /// Collections to keep; none chosen means all of them.
    var collections: Set<UUID> = []
    var fromYear: Int?
    var toYear: Int?
    var trip: UUID?

    var isActive: Bool {
        !collections.isEmpty || fromYear != nil || toYear != nil || trip != nil
    }

    /// Whether `entry` passes: in a chosen collection, in the year range, on the chosen trip.
    func matches(_ entry: Entry, calendar: Calendar = .current) -> Bool {
        if !collections.isEmpty {
            guard let id = entry.item?.collection?.id, collections.contains(id) else { return false }
        }
        if let trip, entry.trip?.id != trip {
            return false
        }
        if fromYear != nil || toYear != nil {
            let year = calendar.component(.year, from: entry.date)
            if let fromYear, year < fromYear {
                return false
            }
            if let toYear, year > toYear {
                return false
            }
        }
        return true
    }

    /// The entries that pass, or all of them when nothing is filtered.
    func apply(to entries: [Entry]) -> [Entry] {
        isActive ? entries.filter { matches($0) } : entries
    }

    /// Sets the first year; the last year is lifted to match if it would end up before it.
    mutating func setFromYear(_ year: Int?) {
        fromYear = year
        if let year, let toYear, toYear < year {
            self.toYear = year
        }
    }

    /// Sets the last year; the first year is lowered to match if it would end up after it.
    mutating func setToYear(_ year: Int?) {
        toYear = year
        if let year, let fromYear, fromYear > year {
            self.fromYear = year
        }
    }

    /// Takes a collection in or out.
    mutating func toggle(collection id: UUID) {
        if collections.contains(id) {
            collections.remove(id)
        } else {
            collections.insert(id)
        }
    }

    /// How many parts are set, for the sheet's "2 filters on".
    var partsOn: Int {
        (collections.isEmpty ? 0 : 1) + (fromYear != nil || toYear != nil ? 1 : 0) + (trip == nil ? 0 : 1)
    }
}

/// The filter for this session (#52: "filters persist per session"): kept for as long as the app
/// is open, so leaving the Atlas and coming back finds the map as it was, and gone on a relaunch.
@MainActor
@Observable
final class AtlasFilterStore {
    static let shared = AtlasFilterStore()

    var filter = AtlasFilter()
}
