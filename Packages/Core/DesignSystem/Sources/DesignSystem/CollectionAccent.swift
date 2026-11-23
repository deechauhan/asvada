/// Accent colours for the built-in collection kinds (and a neutral one for custom collections).
/// Used as keepsake ink: icons, stamps, chips and map pins, so each also meets text contrast.
/// Films use Rose (not plum) so they don't clash with the plum brand.
public enum CollectionAccent: String, CaseIterable, Sendable, Identifiable {
    case cafe
    case restaurant
    case country
    case city
    case airline
    case film
    case custom

    public var id: String {
        rawValue
    }

    public var token: ColorToken {
        switch self {
        case .cafe: ColorToken("accent.cafe", light: "#8A5A2B", dark: "#D9A066")
        case .restaurant: ColorToken("accent.restaurant", light: "#B23A2E", dark: "#FF8A7A")
        case .country: ColorToken("accent.country", light: "#276C4C", dark: "#6FD3A4")
        case .city: ColorToken("accent.city", light: "#4B5BB5", dark: "#9DA8FF")
        case .airline: ColorToken("accent.airline", light: "#1D689E", dark: "#7CC0F2")
        case .film: ColorToken("accent.film", light: "#A3245E", dark: "#F49AC1")
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

    /// The colour's own name, for colour pickers.
    public var colorName: String {
        switch self {
        case .cafe: "Coffee"
        case .restaurant: "Tomato"
        case .country: "Jade"
        case .city: "Indigo"
        case .airline: "Sky"
        case .film: "Rose"
        case .custom: "Slate"
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
