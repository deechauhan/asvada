import Foundation
import Model

/// What a found place leaves on its item: where it is and how to show it again.
public struct PlaceDetails: Sendable, Equatable {
    public let name: String
    /// How items refer to the place ("mk:<MapKit identifier>", or a name-and-coordinates key).
    public let externalRef: String
    public let latitude: Double
    public let longitude: Double
    public let countryCode: String?
    public let address: String?

    public init(name: String, externalRef: String, latitude: Double, longitude: Double, countryCode: String?, address: String?) {
        self.name = name
        self.externalRef = externalRef
        self.latitude = latitude
        self.longitude = longitude
        self.countryCode = countryCode
        self.address = address
    }
}

/// The place details kept in an item's `metadataJSON`.
struct PlaceMetadata: Codable, Equatable {
    var address: String?
}

public extension Repository {
    /// Inserts a found place into `collection`, or updates the item already there for the same
    /// place (by its external reference): name, coordinates, country and address.
    @discardableResult
    func upsertPlace(_ place: PlaceDetails, in collection: ExperienceCollection) -> Item {
        let item = upsertItem(named: place.name, externalRef: place.externalRef, in: collection)
        item.latitude = place.latitude
        item.longitude = place.longitude
        item.countryCode = place.countryCode ?? item.countryCode
        if let address = place.address {
            item.metadataJSON = try? JSONEncoder().encode(PlaceMetadata(address: address))
        }
        return item
    }
}

public extension Item {
    /// The address kept when the place was found, if any.
    var placeAddress: String? {
        guard let metadataJSON else { return nil }
        return (try? JSONDecoder().decode(PlaceMetadata.self, from: metadataJSON))?.address
    }
}
