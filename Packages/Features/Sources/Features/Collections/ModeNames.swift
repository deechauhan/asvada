import Model

/// User-facing names for model enums.
extension RatingMode {
    var displayName: String {
        switch self {
        case .checklist: "Checklist (been / not been)"
        case .log: "Log (every time)"
        case .ranked: "Ranked (compare pairs)"
        case .stars: "Stars"
        }
    }
}

extension ViewMode {
    var displayName: String {
        switch self {
        case .list: "List"
        case .grid: "Grid"
        case .ranked: "Ranking"
        case .progress: "Progress"
        case .map: "Map"
        }
    }
}

extension ItemSource {
    var displayName: String {
        switch self {
        case .mapkit: "Place search"
        case .tmdb: "Film search"
        case .countryCatalog: "Country list"
        case .airlineCatalog: "Airline list"
        case .manual: "Type it in"
        }
    }
}
