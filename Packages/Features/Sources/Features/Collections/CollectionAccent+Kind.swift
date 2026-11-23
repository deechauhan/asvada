import DesignSystem
import Model

extension CollectionAccent {
    /// The accent colour and symbol for a collection kind.
    init(kind: CollectionKind) {
        switch kind {
        case .cafes: self = .cafe
        case .restaurants: self = .restaurant
        case .countries: self = .country
        case .cities: self = .city
        case .airlines: self = .airline
        case .films: self = .film
        case .custom: self = .custom
        }
    }
}

extension ExperienceCollection {
    /// The collection's chosen accent, or its kind's accent if none was chosen.
    var accent: CollectionAccent {
        CollectionAccent(rawValue: accentName) ?? CollectionAccent(kind: kind)
    }
}
