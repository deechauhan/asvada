import CoreGraphics
import Foundation
import Geo

/// Where the stamp pad's reticle is: a country, and the point in the map's unit space it sits on.
struct StampAim: Equatable {
    let code: String
    let point: CGPoint
}

/// A stamp landing: the country flooding with ink from where the stamp hit it.
struct InkBloom: Equatable, Identifiable {
    let id = UUID()
    let code: String
    /// The impact point, in the map's unit space.
    let origin: CGPoint
}

/// The stamp pad's maths and lists, kept out of the views so they're unit-tested
/// (docs/design/INTERACTION.md §6, the flat-map stamp pad).
enum StampPadLogic {
    /// The stamp's foot sits this far above the finger, so the finger never hides the country.
    static let footLift: CGFloat = 44
    /// How much the loupe magnifies.
    static let loupeZoom: CGFloat = 2
    /// The loupe's diameter, in points.
    static let loupeDiameter: CGFloat = 104
    /// How many letters the search needs before the reticle flies (an ISO code needs two).
    static let flyAfterLetters = 3

    /// Where the stamp's foot is for a finger at `finger`, in the map's points.
    static func foot(forFinger finger: CGPoint) -> CGPoint {
        CGPoint(x: finger.x, y: finger.y - footLift)
    }

    /// `point` (in the map's points) in unit space, or nil when it's off the map.
    static func unit(_ point: CGPoint, in size: CGSize) -> CGPoint? {
        guard size.width > 0, size.height > 0 else { return nil }
        let unit = CGPoint(x: point.x / size.width, y: point.y / size.height)
        guard (0 ... 1).contains(unit.x), (0 ... 1).contains(unit.y) else { return nil }
        return unit
    }

    /// Where the loupe's middle goes for a foot at `foot`: beside it, on the side with more room
    /// (never above, where a scroll view or the title would clip it; never below, under the
    /// finger), and kept inside the map's height.
    static func loupePosition(foot: CGPoint, mapSize: CGSize, diameter: CGFloat = loupeDiameter) -> CGPoint {
        let gap = diameter / 2 + 28
        let x = foot.x > mapSize.width / 2 ? foot.x - gap : foot.x + gap
        let half = diameter / 2
        let y = mapSize.height > diameter ? min(max(foot.y, half), mapSize.height - half) : mapSize.height / 2
        return CGPoint(x: x, y: y)
    }

    /// The transform the loupe draws the world with: unit space scaled to `loupeZoom` times the
    /// map, shifted so `centre` (unit space) lands in the middle of a `diameter`-wide circle.
    static func loupeTransform(centre: CGPoint, mapSize: CGSize, diameter: CGFloat = loupeDiameter) -> CGAffineTransform {
        let width = mapSize.width * loupeZoom
        let height = mapSize.height * loupeZoom
        return CGAffineTransform(translationX: diameter / 2 - centre.x * width, y: diameter / 2 - centre.y * height)
            .scaledBy(x: width, y: height)
    }

    /// The country the reticle flies to while typing: the best match once there are three
    /// letters, or an exact two-letter ISO code. Nil while the query is too short or matches nothing.
    static func flyTarget(for query: String, in catalog: CountryCatalog = .shared) -> Country? {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.count == 2, let exact = catalog.country(code: needle) {
            return exact
        }
        guard needle.count >= flyAfterLetters else { return nil }
        return catalog.search(needle).first
    }

    /// The strip of stamps under the map: the search's matches while typing, else the chosen
    /// continent's countries (everywhere for "All"), A to Z. Stamped ones stay put, inked, so
    /// tapping through never moves a stamp out from under your thumb.
    static func strip(continent: Continent?, query: String, in catalog: CountryCatalog = .shared) -> [Country] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pool = trimmed.isEmpty
            ? catalog.countries.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            : catalog.search(trimmed)
        guard let continent else { return pool }
        return pool.filter { $0.continent == continent }
    }

    /// The strip's heading: how many are still to stamp there, never a bare "0".
    static func stripTitle(continent: Continent?, strip: [Country], stamped: Set<String>) -> String {
        let left = strip.count(where: { !stamped.contains($0.code) })
        let place = continent.map { " in \($0.name)" } ?? ""
        if strip.isEmpty {
            return "No country by that name"
        }
        if left == 0 {
            return "Every stamp collected\(place)"
        }
        return "Not yet stamped\(place) · \(left)"
    }

    /// The passport strip's order: newest stamps first. Keeps `order` as it is, puts anything
    /// newly stamped in front, and drops anything washed off.
    static func passportOrder(_ order: [String], stamped: Set<String>) -> [String] {
        let kept = order.filter { stamped.contains($0) }
        let fresh = stamped.subtracting(kept).sorted()
        return fresh + kept
    }

    /// The label on the reticle's glass: the name, and whether it's already stamped.
    static func aimLabel(_ country: Country, stamped: Set<String>) -> String {
        stamped.contains(country.code) ? "\(country.name) · stamped" : country.name
    }
}
