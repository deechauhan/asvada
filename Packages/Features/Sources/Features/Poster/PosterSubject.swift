import Foundation
import Geo
import Model

/// What a poster is of (#71): a trip or a year, with the places to pin on its map and the photos
/// for its collage.
struct PosterSubject: Equatable {
    let title: String
    /// "1 – 7 Jun 2026 · 12 keepsakes".
    let subtitle: String
    /// Every place with coordinates, in date order.
    let points: [GeoPoint]
    /// Small copies of up to `photoLimit` photos, spread through the subject.
    let photos: [Data]

    /// The most photos in the collage.
    static let photoLimit = 6

    /// A trip's poster: its name, dates, places and photos.
    init(trip: Trip) {
        let entries = (trip.entries ?? []).sorted { $0.date < $1.date }
        title = trip.name.isEmpty ? "A trip" : trip.name
        subtitle = "\(TripText.dates(start: trip.start, end: trip.end)) · \(PosterText.count(entries.count))"
        points = Self.points(of: entries)
        photos = Self.photos(of: entries)
    }

    /// A year's poster: everything savoured that year.
    init(year: Int, collections: [ExperienceCollection], calendar: Calendar = .current) {
        let entries = collections.filter { !$0.isHidden }
            .flatMap { $0.items ?? [] }
            .flatMap { $0.entries ?? [] }
            .filter { calendar.component(.year, from: $0.date) == year }
            .sorted { $0.date < $1.date }
        let countries = Set(entries.compactMap { $0.item?.countryCode?.uppercased() })
        title = String(year)
        let places = countries.count == 1 ? "1 country" : "\(countries.count) countries"
        subtitle = "\(PosterText.count(entries.count)) · \(places)"
        points = Self.points(of: entries)
        photos = Self.photos(of: entries)
    }

    init(title: String, subtitle: String, points: [GeoPoint], photos: [Data]) {
        self.title = title
        self.subtitle = subtitle
        self.points = points
        self.photos = photos
    }

    private static func points(of entries: [Entry]) -> [GeoPoint] {
        var seen = Set<GeoPoint>()
        return entries.compactMap { entry in
            guard let item = entry.item, let latitude = item.latitude, let longitude = item.longitude else { return nil }
            let point = GeoPoint(longitude: longitude, latitude: latitude)
            return seen.insert(point).inserted ? point : nil
        }
    }

    private static func photos(of entries: [Entry]) -> [Data] {
        let all = entries.flatMap { ($0.photos ?? []).compactMap(\.thumbnailData) }
        guard all.count > photoLimit else { return all }
        let step = Double(all.count - 1) / Double(photoLimit - 1)
        return (0 ..< photoLimit).map { all[Int((Double($0) * step).rounded())] }
    }
}

/// Where the poster's map looks: the box around its places, with room around the edge, and a
/// sensible minimum so one place isn't a street-level map.
struct PosterRegion: Equatable {
    let centre: GeoPoint
    /// In degrees.
    let latitudeSpan: Double
    let longitudeSpan: Double

    /// The smallest span shown, about a city's width.
    static let minimumSpan = 0.5
    /// How much room is left around the places, as a share of their spread.
    static let margin = 0.3

    /// The whole world, for a poster with no places.
    static let world = PosterRegion(centre: GeoPoint(longitude: 0, latitude: 20), latitudeSpan: 140, longitudeSpan: 340)

    static func fitting(_ points: [GeoPoint]) -> PosterRegion {
        guard let first = points.first else { return world }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for point in points.dropFirst() {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        let latitudeSpan = min(max((maxLat - minLat) * (1 + margin * 2), minimumSpan), 170)
        let longitudeSpan = min(max((maxLon - minLon) * (1 + margin * 2), minimumSpan), 350)
        return PosterRegion(
            centre: GeoPoint(longitude: (minLon + maxLon) / 2, latitude: (minLat + maxLat) / 2),
            latitudeSpan: latitudeSpan,
            longitudeSpan: longitudeSpan,
        )
    }
}

/// The words posters use.
enum PosterText {
    /// "1 keepsake", "12 keepsakes".
    static func count(_ count: Int) -> String {
        count == 1 ? "1 keepsake" : "\(count) keepsakes"
    }

    /// The file name for a poster, without extension: "Asvada poster · Lisbon in June".
    static func fileName(for title: String) -> String {
        let safe = title.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
        return "Asvada poster · \(safe)"
    }
}
