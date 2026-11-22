/// What a collection holds. Built-in kinds get seeded collections; users add `custom` ones.
public enum CollectionKind: String, Codable, CaseIterable, Sendable {
    case cafes
    case restaurants
    case countries
    case cities
    case airlines
    case films
    case custom
}

/// How items in a collection are rated.
public enum RatingMode: String, Codable, CaseIterable, Sendable {
    /// Been / not been, with completion against a known set (countries).
    case checklist
    /// Repeatable dated entries (films, flights).
    case log
    /// Ordered list built by pairwise comparison (cafés, restaurants).
    case ranked
    /// Star rating fallback.
    case stars
}

/// A collection's default presentation.
public enum ViewMode: String, Codable, CaseIterable, Sendable {
    case list
    case grid
    case ranked
    case progress
    case map
}

/// Where a collection's items come from.
public enum ItemSource: String, Codable, CaseIterable, Sendable {
    case mapkit
    case tmdb
    case countryCatalog
    case airlineCatalog
    case manual
}
