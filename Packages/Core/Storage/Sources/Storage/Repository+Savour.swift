import Foundation
import Model

/// What quick-log records about one encounter: when, how it landed, a note, and for ranked
/// collections where it now sits.
public struct Savouring: Sendable, Equatable {
    public var date: Date
    /// 1–5 for star collections; nil elsewhere.
    public var rating: Double?
    public var note: String
    /// The item's new place in its collection's ranking (0 is the top), when a duel placed it.
    /// Nil keeps any place it already had.
    public var rankPosition: Int?

    public init(date: Date = .now, rating: Double? = nil, note: String = "", rankPosition: Int? = nil) {
        self.date = date
        self.rating = rating
        self.note = note
        self.rankPosition = rankPosition
    }
}

public extension Repository {
    /// Seals one encounter with `item`: adds the entry (stamping its country if it's a place),
    /// places it in its collection's ranking when a duel decided where, and saves.
    @discardableResult
    func savour(_ item: Item, _ savouring: Savouring) throws -> Entry {
        let note = savouring.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = addEntry(to: item, date: savouring.date, rating: savouring.rating, notes: note)
        if let position = savouring.rankPosition, let collection = item.collection {
            place(item, at: position, in: collection)
        }
        try save()
        return entry
    }
}
