import Foundation
import Geo
import Model
import Storage

/// What onboarding writes: the countries you stamped, and your first keepsake.
@MainActor
enum OnboardingStore {
    /// The UserDefaults key that records onboarding has been seen (finished or skipped).
    nonisolated static let completedKey = "onboarding.completed"

    /// Adds each stamped country to the Countries collection (once, keyed by ISO code). Returns how
    /// many are stamped there now.
    @discardableResult
    static func stamp(_ codes: Set<String>, in repository: Repository) throws -> Int {
        guard let countries = try collection(.countries, in: repository) else { return 0 }
        for code in codes.sorted() {
            guard let country = CountryCatalog.shared.country(code: code) else { continue }
            let item = repository.upsertItem(named: country.name, externalRef: "iso:\(country.code)", in: countries)
            item.countryCode = country.code
        }
        try repository.save()
        return countries.items?.count ?? 0
    }

    /// Logs the first keepsake: an item named `name` in the collection of `kind`, with one entry
    /// today. Returns the entry, or nil if that collection isn't there.
    @discardableResult
    static func savour(_ name: String, kind: CollectionKind, in repository: Repository) throws -> Entry? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let collection = try collection(kind, in: repository) else { return nil }
        let item = repository.upsertItem(named: trimmed, externalRef: nil, in: collection)
        let entry = repository.addEntry(to: item)
        try repository.save()
        return entry
    }

    private static func collection(_ kind: CollectionKind, in repository: Repository) throws -> ExperienceCollection? {
        try repository.collections(includeHidden: true).first { $0.kind == kind }
    }
}
