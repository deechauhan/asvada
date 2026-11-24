import CoreGraphics
import Geo
import Testing
@testable import Features

@MainActor
struct StampPadTests {
    // MARK: - Aiming

    @Test func theFootSitsAboveTheFinger() {
        let foot = StampPadLogic.foot(forFinger: CGPoint(x: 100, y: 200))
        #expect(foot == CGPoint(x: 100, y: 200 - StampPadLogic.footLift))
    }

    @Test func pointsOffTheMapAreNotInUnitSpace() {
        let size = CGSize(width: 200, height: 100)
        #expect(StampPadLogic.unit(CGPoint(x: 50, y: 25), in: size) == CGPoint(x: 0.25, y: 0.25))
        #expect(StampPadLogic.unit(CGPoint(x: 50, y: -1), in: size) == nil)
        #expect(StampPadLogic.unit(CGPoint(x: 201, y: 50), in: size) == nil)
        #expect(StampPadLogic.unit(.zero, in: .zero) == nil)
    }

    @Test func theLoupeCentresTheFootAtTwiceTheSize() {
        let size = CGSize(width: 300, height: 130)
        let diameter = StampPadLogic.loupeDiameter
        let transform = StampPadLogic.loupeTransform(centre: CGPoint(x: 0.4, y: 0.6), mapSize: size)
        let middle = CGPoint(x: 0.4, y: 0.6).applying(transform)
        #expect(abs(middle.x - diameter / 2) < 0.001)
        #expect(abs(middle.y - diameter / 2) < 0.001)
        // One unit across the map is twice the map's width in the loupe.
        let right = CGPoint(x: 0.5, y: 0.6).applying(transform)
        #expect(abs((right.x - middle.x) - 0.1 * size.width * StampPadLogic.loupeZoom) < 0.001)
    }

    @Test func theLoupeSitsBesideTheFootInsideTheMap() {
        let size = CGSize(width: 360, height: 150)
        let half = StampPadLogic.loupeDiameter / 2
        let left = StampPadLogic.loupePosition(foot: CGPoint(x: 300, y: 10), mapSize: size)
        #expect(left.x < 300)
        #expect(left.y == half)
        let right = StampPadLogic.loupePosition(foot: CGPoint(x: 40, y: 149), mapSize: size)
        #expect(right.x > 40)
        #expect(right.y == size.height - half)
    }

    @Test func aMapTooShortForTheLoupeCentresItVertically() {
        let size = CGSize(width: 200, height: 80)
        #expect(StampPadLogic.loupePosition(foot: CGPoint(x: 20, y: 5), mapSize: size).y == 40)
    }

    @Test func everyDrawnCountryHasItsAnchorOnTheMap() {
        let world = InkWorld.shared
        let outside = world.countries.filter { !(0 ... 1).contains($0.anchor.x) || !(0 ... 1).contains($0.anchor.y) }
        #expect(outside.isEmpty)
        // The United States is aimed at the lower 48, not at a point between them and Alaska.
        let usa = world.shape(code: "US")
        #expect(usa.map { world.code(atUnit: $0.anchor) } == "US")
    }

    @Test func overlappingOutlinesPickTheSmallestCountry() {
        // Lesotho sits inside South Africa's outer ring.
        let lesotho = InkWorld.shared.shape(code: "LS")
        #expect(lesotho.map { InkWorld.shared.code(atUnit: $0.anchor) } == "LS")
    }

    // MARK: - Search

    @Test func searchFliesAfterThreeLettersOrAnExactCode() {
        #expect(StampPadLogic.flyTarget(for: "Ja") == nil)
        #expect(StampPadLogic.flyTarget(for: "Jap")?.code == "JP")
        #expect(StampPadLogic.flyTarget(for: "pt")?.code == "PT")
        #expect(StampPadLogic.flyTarget(for: "  ") == nil)
        #expect(StampPadLogic.flyTarget(for: "Xyzzy") == nil)
    }

    // MARK: - Strips

    @Test func aContinentDealsItsCountriesAToZ() {
        let strip = StampPadLogic.strip(continent: .oceania, query: "")
        let continents = Set(strip.map(\.continent))
        let names = strip.map(\.name)
        let sorted = names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        #expect(continents == [.oceania])
        #expect(names == sorted)
        #expect(names.contains("Australia"))
    }

    @Test func typingNarrowsTheStrip() {
        let strip = StampPadLogic.strip(continent: nil, query: "port")
        #expect(strip.map(\.code) == ["PT"])
        #expect(StampPadLogic.strip(continent: .asia, query: "port").isEmpty)
    }

    @Test func allDealsEveryCountry() {
        #expect(StampPadLogic.strip(continent: nil, query: "").count == CountryCatalog.shared.countries.count)
    }

    @Test func theStripTitleCountsWhatsLeftAndNeverSaysZero() {
        let strip = StampPadLogic.strip(continent: nil, query: "port")
        #expect(StampPadLogic.stripTitle(continent: nil, strip: strip, stamped: []) == "Not yet stamped · 1")
        #expect(StampPadLogic.stripTitle(continent: .europe, strip: strip, stamped: ["PT"]) == "Every stamp collected in Europe")
        #expect(StampPadLogic.stripTitle(continent: nil, strip: [], stamped: []) == "No country by that name")
    }

    // MARK: - Passport strip

    @Test func newStampsGoFirstAndWashedOffOnesLeave() {
        var order = StampPadLogic.passportOrder([], stamped: ["PT", "JP"])
        #expect(order == ["JP", "PT"])
        order = StampPadLogic.passportOrder(order, stamped: ["PT", "JP", "BR"])
        #expect(order == ["BR", "JP", "PT"])
        order = StampPadLogic.passportOrder(order, stamped: ["PT", "BR"])
        #expect(order == ["BR", "PT"])
    }

    @Test func theReticleSaysWhenACountryIsAlreadyStamped() throws {
        let japan = try #require(CountryCatalog.shared.country(code: "JP"))
        #expect(StampPadLogic.aimLabel(japan, stamped: []) == "Japan")
        #expect(StampPadLogic.aimLabel(japan, stamped: ["JP"]) == "Japan · stamped")
    }
}
