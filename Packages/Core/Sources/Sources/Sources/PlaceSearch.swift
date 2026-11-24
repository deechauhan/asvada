import Foundation
import Geo
import MapKit

/// A place found by search: what Asvada keeps of it. Country codes come from the bundled outlines
/// (offline), so they're right even where MapKit's address is sparse.
public struct PlaceResult: Sendable, Hashable, Identifiable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    /// A one-line address, e.g. "18 Clerkenwell Rd, London".
    public let address: String?
    /// ISO 3166-1 alpha-2, e.g. "GB".
    public let countryCode: String?
    /// MapKit's stable identifier for the place, when it has one.
    public let mapItemIdentifier: String?

    public init(
        name: String,
        latitude: Double,
        longitude: Double,
        address: String? = nil,
        countryCode: String? = nil,
        mapItemIdentifier: String? = nil,
    ) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        let point = GeoPoint(longitude: longitude, latitude: latitude)
        self.countryCode = countryCode ?? CountryCatalog.shared.country(at: point)?.code
        self.mapItemIdentifier = mapItemIdentifier
    }

    /// How items refer to this place: "mk:<identifier>", or, without one, the name and the
    /// coordinates to about 10 m so the same café found twice is one item.
    public var externalRef: String {
        if let mapItemIdentifier {
            return "mk:\(mapItemIdentifier)"
        }
        let key = name.lowercased().trimmingCharacters(in: .whitespaces)
        return String(format: "place:%@@%.4f,%.4f", key, latitude, longitude)
    }

    public var id: String {
        externalRef
    }
}

/// What kind of place a search looks for.
public enum PlaceKind: Sendable, CaseIterable {
    case cafe
    case restaurant
    case city
    case any

    /// The MapKit categories that count, or `nil` for no filter.
    var categories: [MKPointOfInterestCategory]? {
        switch self {
        case .cafe: [.cafe, .bakery]
        case .restaurant: [.restaurant, .foodMarket, .brewery, .winery]
        case .city, .any: nil
        }
    }
}

/// Searching for places by name, optionally near somewhere.
public protocol PlaceSearching: Sendable {
    /// Places matching `query`, nearest first when `near` is given. Without `near` (no location
    /// permission, say) it's a plain worldwide search.
    func search(_ query: String, kind: PlaceKind, near: GeoPoint?) async throws -> [PlaceResult]
}

/// Place search with MapKit's `MKLocalSearch`: no API key, nothing sent but the query and,
/// if given, the area to search around.
public struct MapKitPlaceSearch: PlaceSearching {
    /// How far around `near` to look first, in metres.
    public static let nearbyRadius: CLLocationDistance = 5000

    public init() {}

    public func search(_ query: String, kind: PlaceKind, near: GeoPoint?) async throws -> [PlaceResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = kind == .city ? .address : .pointOfInterest
        if let categories = kind.categories {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
        }
        if let near {
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: near.latitude, longitude: near.longitude),
                latitudinalMeters: Self.nearbyRadius,
                longitudinalMeters: Self.nearbyRadius,
            )
        }
        let response = try await MKLocalSearch(request: request).start()
        let places = response.mapItems.compactMap(PlaceResult.init(mapItem:))
        guard let near else { return places }
        return Self.nearestFirst(places, to: near)
    }

    /// `places` ordered by distance from `point` (stable for ties).
    static func nearestFirst(_ places: [PlaceResult], to point: GeoPoint) -> [PlaceResult] {
        let distances: [Double] = places.map { kilometres(from: point, to: $0) }
        let order: [Int] = places.indices.sorted { lhs, rhs in
            distances[lhs] == distances[rhs] ? lhs < rhs : distances[lhs] < distances[rhs]
        }
        return order.map { places[$0] }
    }

    /// An equirectangular distance in kilometres: plenty for ordering places within a city.
    static func kilometres(from point: GeoPoint, to place: PlaceResult) -> Double {
        let earthRadius = 6371.0
        let radians = Double.pi / 180
        let meanLatitude = (point.latitude + place.latitude) / 2 * radians
        let east = (place.longitude - point.longitude) * radians * cos(meanLatitude)
        let north = (place.latitude - point.latitude) * radians
        return (east * east + north * north).squareRoot() * earthRadius
    }
}

extension PlaceResult {
    /// What Asvada keeps of a MapKit result, or `nil` if it has no name.
    init?(mapItem: MKMapItem) {
        guard let name = mapItem.name, !name.isEmpty else { return nil }
        let coordinate = mapItem.location.coordinate
        self.init(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: mapItem.address?.shortAddress ?? mapItem.address?.fullAddress,
            mapItemIdentifier: mapItem.identifier?.rawValue,
        )
    }
}
