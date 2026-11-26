import Foundation
import Model

/// How a search found an item: by its own name, or by something you wrote or tagged on an entry.
enum SearchMatch: Equatable {
    case name
    case person(String)
    case tag(String)
    case note(String)

    /// What a result row says under the item's name; none when the name itself matched.
    var caption: String? {
        switch self {
        case .name: nil
        case let .person(name): "with \(name)"
        case let .tag(name): "#\(name)"
        case let .note(snippet): "“\(snippet)”"
        }
    }

    /// Name matches come first in a group, then people, tags and notes.
    fileprivate var rank: Int {
        switch self {
        case .name: 0
        case .person: 1
        case .tag: 2
        case .note: 3
        }
    }
}

/// One item the search found, and why.
struct SearchHit: Identifiable {
    let item: Item
    let match: SearchMatch

    var id: UUID {
        item.id
    }
}

/// The hits in one collection.
struct SearchGroup: Identifiable {
    let collection: ExperienceCollection
    let hits: [SearchHit]

    var id: UUID {
        collection.id
    }
}

/// Search across everything (#45): items by name, and entries by their notes, the people you were
/// with and their tags. Matching ignores case and accents, like the system's own search.
/// Results are grouped by collection in the cabinet's order; drawers you've put away stay out.
enum GlobalSearch {
    /// The longest note snippet shown under a result.
    static let snippetLength = 80

    /// The query without surrounding spaces; empty means "not searching".
    static func trimmed(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The items matching `query`, grouped by collection.
    static func groups(for query: String, in items: [Item]) -> [SearchGroup] {
        let needle = trimmed(query)
        guard !needle.isEmpty else { return [] }
        var hitsByCollection: [UUID: [SearchHit]] = [:]
        var collections: [UUID: ExperienceCollection] = [:]
        for item in items {
            guard let collection = item.collection, !collection.isHidden,
                  let match = match(item, needle: needle) else { continue }
            hitsByCollection[collection.id, default: []].append(SearchHit(item: item, match: match))
            collections[collection.id] = collection
        }
        let ordered = collections.values.sorted { lhs, rhs in
            lhs.sortIndex != rhs.sortIndex ? lhs.sortIndex < rhs.sortIndex : lhs.name < rhs.name
        }
        return ordered.map { collection in
            let hits = (hitsByCollection[collection.id] ?? []).sorted { lhs, rhs in
                lhs.match.rank != rhs.match.rank
                    ? lhs.match.rank < rhs.match.rank
                    : lhs.item.name.localizedStandardCompare(rhs.item.name) == .orderedAscending
            }
            return SearchGroup(collection: collection, hits: hits)
        }
    }

    /// Why `item` matches `needle`, or `nil` if it doesn't. The name wins; then people, tags and
    /// notes, looking at the newest entry first.
    static func match(_ item: Item, needle: String) -> SearchMatch? {
        if item.name.localizedStandardContains(needle) {
            return .name
        }
        let entries = (item.entries ?? []).sorted { $0.date > $1.date }
        for entry in entries {
            if let person = (entry.people ?? []).first(where: { $0.name.localizedStandardContains(needle) }) {
                return .person(person.name)
            }
        }
        for entry in entries {
            if let tag = (entry.tags ?? []).first(where: { $0.name.localizedStandardContains(needle) }) {
                return .tag(tag.name)
            }
        }
        for entry in entries where entry.notes.localizedStandardContains(needle) {
            return .note(snippet(of: entry.notes))
        }
        return nil
    }

    /// The first line of a note, cut to `snippetLength`.
    static func snippet(of note: String) -> String {
        let firstLine = note
            .split(whereSeparator: \.isNewline)
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        guard firstLine.count > snippetLength else { return firstLine }
        return String(firstLine.prefix(snippetLength)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
