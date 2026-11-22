/// Accent colours for the built-in collection kinds (and a neutral one for custom collections).
/// Used to tint icons, chips and map pins, so each also meets text contrast.
public enum CollectionAccent: String, CaseIterable, Sendable, Identifiable {
    case cafe
    case restaurant
    case country
    case city
    case airline
    case film
    case custom

    public var id: String { rawValue }

    public var token: ColorToken {
        switch self {
        case .cafe: ColorToken("accent.cafe", light: "#8A5A2B", dark: "#D9A066")
        case .restaurant: ColorToken("accent.restaurant", light: "#B23A2E", dark: "#FF8A7A")
        case .country: ColorToken("accent.country", light: "#2B7553", dark: "#6FD3A4")
        case .city: ColorToken("accent.city", light: "#4B5BB5", dark: "#9DA8FF")
        case .airline: ColorToken("accent.airline", light: "#1D689E", dark: "#7CC0F2")
        case .film: ColorToken("accent.film", light: "#8E3B8A", dark: "#E39BDD")
        case .custom: ColorToken("accent.custom", light: "#56606E", dark: "#AEB8C6")
        }
    }

    /// Default SF Symbol for the kind.
    public var symbol: String {
        switch self {
        case .cafe: "cup.and.saucer.fill"
        case .restaurant: "fork.knife"
        case .country: "globe.europe.africa.fill"
        case .city: "building.2.fill"
        case .airline: "airplane"
        case .film: "film.fill"
        case .custom: "star.fill"
        }
    }

    public var displayName: String {
        switch self {
        case .cafe: "Cafés"
        case .restaurant: "Restaurants"
        case .country: "Countries"
        case .city: "Cities"
        case .airline: "Airlines"
        case .film: "Films"
        case .custom: "Custom"
        }
    }
}
