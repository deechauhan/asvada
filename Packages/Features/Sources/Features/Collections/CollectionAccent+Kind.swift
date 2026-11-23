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
