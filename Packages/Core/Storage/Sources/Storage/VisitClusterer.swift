import Foundation
import Geo

/// A photo with a place and a time: all the scan keeps of it.
public struct PhotoSighting: Sendable, Equatable, Hashable {
    public let id: String
    public let date: Date
    public let point: GeoPoint

    public init(id: String, date: Date, point: GeoPoint) {
        self.id = id
        self.date = date
        self.point = point
    }
}

/// A run of photos taken in one place over a few days: a visit someone might want to add (#64).
public struct VisitCluster: Sendable, Equatable, Identifiable {
    /// The first photo's id, stable between scans of the same library.
    public let id: String
    public let start: Date
    public let end: Date
    /// The average place of the photos.
    public let centre: GeoPoint
    public let photoCount: Int
    /// Up to `VisitClusterer.sampleCount` photos, spread through the visit, to show.
    public let sampleIDs: [String]
    /// The country the visit was in, when the photos were on land (or near a coast).
    public let countryCode: String?
    public let countryName: String?

    public init(
        id: String,
        start: Date,
        end: Date,
        centre: GeoPoint,
        photoCount: Int,
        sampleIDs: [String],
        countryCode: String?,
        countryName: String?,
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.centre = centre
        self.photoCount = photoCount
        self.sampleIDs = sampleIDs
        self.countryCode = countryCode
        self.countryName = countryName
    }
}

/// Groups photos into visits, on the phone and from nothing but where and when each was taken.
///
/// Photos are taken in time order; one joins the visit before it unless more than
/// `maximumGap` has passed or it is more than `maximumDistance` from the visit's centre, so a
/// week in Lisbon with a day trip to Sintra is two visits, and flying home starts another. Visits
/// of fewer than `minimumPhotos` are dropped: one stray photo is not somewhere you went.
public enum VisitClusterer {
    public static let maximumGap: TimeInterval = 36 * 3600
    /// In kilometres.
    public static let maximumDistance = 40.0
    public static let minimumPhotos = 3
    public static let sampleCount = 4

    /// The visits in `sightings` (any order), earliest first.
    public static func clusters(from sightings: [PhotoSighting], catalog: CountryCatalog = .shared) -> [VisitCluster] {
        var visits: [[PhotoSighting]] = []
        var current: [PhotoSighting] = []
        var centre: GeoPoint?
        for sighting in sightings.sorted(by: { $0.date < $1.date }) {
            if let last = current.last, let middle = centre,
               sighting.date.timeIntervalSince(last.date) <= maximumGap,
               kilometres(from: middle, to: sighting.point) <= maximumDistance
            {
                current.append(sighting)
            } else {
                if !current.isEmpty {
                    visits.append(current)
                }
                current = [sighting]
            }
            centre = average(of: current)
        }
        if !current.isEmpty {
            visits.append(current)
        }
        return visits
            .filter { $0.count >= minimumPhotos }
            .map { cluster(of: $0, catalog: catalog) }
    }

    private static func cluster(of photos: [PhotoSighting], catalog: CountryCatalog) -> VisitCluster {
        let middle = average(of: photos)
        let country = catalog.country(at: middle)
        return VisitCluster(
            id: photos[0].id,
            start: photos[0].date,
            end: photos[photos.count - 1].date,
            centre: middle,
            photoCount: photos.count,
            sampleIDs: samples(of: photos),
            countryCode: country?.code,
            countryName: country?.name,
        )
    }

    /// Up to `sampleCount` ids spread evenly through the visit.
    static func samples(of photos: [PhotoSighting]) -> [String] {
        guard photos.count > sampleCount else { return photos.map(\.id) }
        let step = Double(photos.count - 1) / Double(sampleCount - 1)
        return (0 ..< sampleCount).map { photos[Int((Double($0) * step).rounded())].id }
    }

    private static func average(of photos: [PhotoSighting]) -> GeoPoint {
        let count = Double(photos.count)
        let latitude = photos.reduce(0) { $0 + $1.point.latitude } / count
        // Longitudes are averaged as angles, so a visit that crosses the date line doesn't land
        // on the far side of the world.
        let x = photos.reduce(0) { $0 + cos($1.point.longitude * .pi / 180) } / count
        let y = photos.reduce(0) { $0 + sin($1.point.longitude * .pi / 180) } / count
        return GeoPoint(longitude: atan2(y, x) * 180 / .pi, latitude: latitude)
    }

    /// The great-circle distance between two points, in kilometres.
    static func kilometres(from lhs: GeoPoint, to rhs: GeoPoint) -> Double {
        let radius = 6371.0
        let lat1 = lhs.latitude * .pi / 180
        let lat2 = rhs.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (rhs.longitude - lhs.longitude) * .pi / 180
        let haversine = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, haversine.squareRoot()))
    }
}
