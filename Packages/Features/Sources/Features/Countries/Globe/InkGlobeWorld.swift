import CoreGraphics
import Geo
import simd
import SwiftUI

/// One outline ready for the globe: its points on the unit sphere, worked out once, at two levels
/// of detail (the coarse one is drawn while the globe moves), with where each point sits on the
/// flat ink map for the unroll morph.
struct GlobeRing: Sendable {
    let points: [SIMD3<Double>]
    let flat: [CGPoint]
    /// The outline in longitude and latitude, for asking whether it holds a point.
    let geo: [GeoPoint]
    let coarse: [SIMD3<Double>]
    let coarseFlat: [CGPoint]
    /// The middle of its points, and how far (as sin of the angle) they reach from it: enough to
    /// skip a ring that's wholly round the back, or draw one wholly in front without clipping.
    let middle: SIMD3<Double>
    let reach: Double
    let minLongitude: Double
    let maxLongitude: Double
    let minLatitude: Double
    let maxLatitude: Double

    /// Whether the outline holds `point` (a ray cast in longitude and latitude).
    func contains(_ point: GeoPoint) -> Bool {
        guard (minLongitude ... maxLongitude).contains(point.longitude),
              (minLatitude ... maxLatitude).contains(point.latitude),
              geo.count > 2
        else { return false }
        var inside = false
        var previous = geo[geo.count - 1]
        for here in geo {
            if (here.latitude > point.latitude) != (previous.latitude > point.latitude) {
                let slope = (previous.longitude - here.longitude) / (previous.latitude - here.latitude)
                if point.longitude < here.longitude + slope * (point.latitude - here.latitude) {
                    inside.toggle()
                }
            }
            previous = here
        }
        return inside
    }
}

/// A country on the globe: its outlines, where the reticle aims for it, and whether it's small.
struct GlobeCountry: Sendable {
    let code: String
    let rings: [GlobeRing]
    let anchor: GlobeAnchor
    /// Its bounding box in square degrees: small ones get disambiguation chips.
    let area: Double

    static let smallArea = 6.0

    var isSmall: Bool {
        area < Self.smallArea
    }
}

/// Every country on the unit sphere, built once from the bundled outlines. Antarctica is left
/// out, as on the flat map.
struct InkGlobeWorld: Sendable {
    static let shared = InkGlobeWorld(catalog: .shared, flat: .shared)

    /// Points closer than this (degrees of arc) are merged: about a point at rest on a phone.
    static let fineStep = 0.3
    /// While it moves the globe is drawn from a coarser outline.
    static let coarseStep = 1.0

    let countries: [GlobeCountry]
    let land: [GlobeRing]
    let anchors: [GlobeAnchor]
    private let byCode: [String: GlobeCountry]

    init(catalog: CountryCatalog, flat: InkWorld) {
        countries = catalog.countries.filter { $0.code != "AQ" }.map { country in
            let rings = country.outlines.compactMap { Self.ring($0, flat: flat) }
            let largest = country.outlines.max { Self.boxArea($0) < Self.boxArea($1) } ?? []
            let anchor = Self.boxMiddle(largest) ?? GeoPoint(longitude: 0, latitude: 0)
            return GlobeCountry(
                code: country.code,
                rings: rings,
                anchor: GlobeAnchor(code: country.code, point: anchor),
                area: country.bounds.area,
            )
        }
        land = catalog.unassignedLand.compactMap { Self.ring($0, flat: flat) }
        anchors = countries.map(\.anchor)
        byCode = Dictionary(countries.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func country(code: String) -> GlobeCountry? {
        byCode[code.uppercased()]
    }

    // MARK: - Building

    static func ring(_ outline: [GeoPoint], flat: InkWorld) -> GlobeRing? {
        guard outline.count > 2 else { return nil }
        let vectors = outline.map(GlobeSphere.vector)
        let fine = thin(vectors, step: fineStep)
        let coarse = thin(vectors, step: coarseStep)
        var sum = vectors.reduce(SIMD3<Double>.zero, +)
        if simd_length(sum) < 1e-9 {
            sum = vectors[0]
        }
        let middle = simd_normalize(sum)
        let widest = vectors.map { GlobeSphere.degrees(between: middle, and: $0) }.max() ?? 180
        return GlobeRing(
            points: fine.map { vectors[$0] },
            flat: fine.map { flat.unit(outline[$0]) },
            geo: fine.map { outline[$0] },
            coarse: coarse.map { vectors[$0] },
            coarseFlat: coarse.map { flat.unit(outline[$0]) },
            middle: middle,
            reach: widest < 90 ? sin(widest * .pi / 180) : 2,
            minLongitude: outline.map(\.longitude).min() ?? 0,
            maxLongitude: outline.map(\.longitude).max() ?? 0,
            minLatitude: outline.map(\.latitude).min() ?? 0,
            maxLatitude: outline.map(\.latitude).max() ?? 0,
        )
    }

    /// The indices of the points to keep: each at least `step` degrees on from the last kept
    /// one. A ring keeps at least three points, so a tiny country still has a shape.
    static func thin(_ vectors: [SIMD3<Double>], step: Double) -> [Int] {
        guard vectors.count > 3 else { return Array(vectors.indices) }
        let limit = cos(step * .pi / 180)
        var kept = [0]
        for index in vectors.indices.dropFirst() where simd_dot(vectors[kept[kept.count - 1]], vectors[index]) < limit {
            kept.append(index)
        }
        guard kept.count < 3 else { return kept }
        let stride = max(vectors.count / 3, 1)
        return [0, stride, min(stride * 2, vectors.count - 1)]
    }

    private static func boxArea(_ ring: [GeoPoint]) -> Double {
        guard let box = box(ring) else { return 0 }
        let middle = (box.minLatitude + box.maxLatitude) / 2
        return (box.maxLongitude - box.minLongitude) * (box.maxLatitude - box.minLatitude) * cos(middle * .pi / 180)
    }

    private static func boxMiddle(_ ring: [GeoPoint]) -> GeoPoint? {
        box(ring).map {
            GeoPoint(longitude: ($0.minLongitude + $0.maxLongitude) / 2, latitude: ($0.minLatitude + $0.maxLatitude) / 2)
        }
    }

    private struct Box {
        let minLongitude: Double
        let maxLongitude: Double
        let minLatitude: Double
        let maxLatitude: Double
    }

    private static func box(_ ring: [GeoPoint]) -> Box? {
        let longitudes = ring.map(\.longitude)
        let latitudes = ring.map(\.latitude)
        guard let west = longitudes.min(), let east = longitudes.max(), let south = latitudes.min(), let north = latitudes.max()
        else { return nil }
        return Box(minLongitude: west, maxLongitude: east, minLatitude: south, maxLatitude: north)
    }
}
