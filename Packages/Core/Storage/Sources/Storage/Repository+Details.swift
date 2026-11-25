import Foundation
import Model
import SwiftData

/// People and tags on entries: typed as names, stored once each and shared between entries.
public enum DetailNames {
    /// `names` trimmed, without blanks, and without repeats (ignoring case and accents; the first
    /// spelling wins).
    public static func cleaned(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert(fold($0)).inserted }
    }

    /// Up to `limit` of `known` that start with `prefix` (ignoring case and accents), leaving out
    /// any already chosen. An empty prefix suggests the first `limit`.
    public static func suggestions(_ known: [String], prefix: String, excluding chosen: [String], limit: Int = 5) -> [String] {
        let needle = fold(prefix.trimmingCharacters(in: .whitespacesAndNewlines))
        let taken = Set(chosen.map(fold))
        return Array(known.filter { !taken.contains(fold($0)) && (needle.isEmpty || fold($0).hasPrefix(needle)) }.prefix(limit))
    }

    static func fold(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

public extension Repository {
    /// Every tag's name, the most used first.
    func tagNames() -> [String] {
        let tags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        return Self.byUse(tags.map { ($0.name, $0.entries?.count ?? 0) })
    }

    /// Everyone's name, the most often with you first.
    func peopleNames() -> [String] {
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        return Self.byUse(people.map { ($0.name, $0.entries?.count ?? 0) })
    }

    /// Sets `entry`'s tags to `names`, reusing tags that already exist (same name, any case).
    func setTags(_ names: [String], on entry: Entry) {
        let existing = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        entry.tags = DetailNames.cleaned(names).map { name in
            existing.first { DetailNames.fold($0.name) == DetailNames.fold(name) } ?? {
                let tag = Tag(name: name)
                context.insert(tag)
                return tag
            }()
        }
    }

    /// Sets who was with you on `entry` to `names`, reusing people who already exist.
    func setPeople(_ names: [String], on entry: Entry) {
        let existing = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        entry.people = DetailNames.cleaned(names).map { name in
            existing.first { DetailNames.fold($0.name) == DetailNames.fold(name) } ?? {
                let person = Person(name: name)
                context.insert(person)
                return person
            }()
        }
    }

    /// Saves `details` onto `entry` straight away (the entry editor saves every change).
    func update(_ entry: Entry, with details: EntryDetails) throws {
        entry.date = details.date
        entry.notes = details.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        setPeople(details.people, on: entry)
        setTags(details.tags, on: entry)
        try save()
    }

    /// The entry with `id`, if it still exists.
    func entry(id: UUID) -> Entry? {
        var descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func byUse(_ names: [(String, Int)]) -> [String] {
        names
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.localizedStandardCompare($1.0) == .orderedAscending }
            .map(\.0)
    }
}

/// The parts of an entry you fill in after the fact: when, a note, who with, and tags.
public struct EntryDetails: Sendable, Equatable {
    public var date: Date
    public var notes: String
    public var people: [String]
    public var tags: [String]

    public init(date: Date = .now, notes: String = "", people: [String] = [], tags: [String] = []) {
        self.date = date
        self.notes = notes
        self.people = people
        self.tags = tags
    }

    /// What `entry` holds now.
    public init(_ entry: Entry) {
        self.init(
            date: entry.date,
            notes: entry.notes,
            people: (entry.people ?? []).map(\.name),
            tags: (entry.tags ?? []).map(\.name),
        )
    }
}
