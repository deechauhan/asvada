import Foundation
import Testing
@testable import DesignSystem

@MainActor
struct KeepsakeTests {
    @Test func seedIsStableAcrossCalls() {
        #expect(Seed.hash("JP") == Seed.hash("JP"))
        #expect(Seed.hash("JP") != Seed.hash("PT"))
        // FNV-1a of the empty string is the offset basis: proves we don't use randomised hashValue.
        #expect(Seed.hash("") == 0xCBF2_9CE4_8422_2325)
    }

    @Test(arguments: ["a", "entry-1", "6F9619FF-8B86-D011-B42D-00C04FC964FF", "JP", "🇯🇵"])
    func tiltStaysWithinLimits(id: String) {
        let keepsake = Tilt.degrees(for: id)
        let stamp = Tilt.degrees(for: id, max: Tilt.stampMax)
        #expect(abs(keepsake) <= Tilt.keepsakeMax)
        #expect(abs(stamp) <= Tilt.stampMax)
        #expect(Tilt.degrees(for: id) == keepsake)
    }

    @Test func stampShapeIsDeterministicAndCaseInsensitive() {
        #expect(StampShape.forCode("jp") == StampShape.forCode("JP"))
        #expect(StampShape.forCode("JP") == StampShape.forCode("JP"))
    }

    @Test func allStampShapesAppearAcrossCountries() {
        let codes = ["JP", "PT", "IN", "IS", "PE", "KE", "FR", "DE", "US", "BR", "AU", "NZ", "ZA", "MX", "CA", "IT"]
        let shapes = Set(codes.map { String(describing: StampShape.forCode($0)) })
        #expect(shapes.count == StampShape.allCases.count)
    }

    @Test func stampDatesUseDayMonthYearWithMiddots() throws {
        let date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2025, month: 4, day: 3)))
        #expect(PassportStamp.stampDate(date) == "03·04·25")
    }

    @Test func spokenSummaries() {
        let date = try? Date("2025-04-03", strategy: .iso8601.year().month().day())
        let stamp = PassportStamp(country: "Japan", code: "JP", date: date)
        #expect(stamp.accessibilitySummary.hasPrefix("Passport stamp, Japan, entered "))
        #expect(PassportStamp(country: "Peru", code: "PE").accessibilitySummary == "Passport stamp, Peru")
        let tag = LuggageTag(
            collection: "Concerts",
            title: "Radiohead",
            detail: "12·07·26",
            icon: "music.note",
            ink: Palette.brand,
        )
        #expect(tag.accessibilitySummary == "Concerts, Radiohead, 12·07·26")
    }
}

@MainActor
struct SealTests {
    @Test func holdMatchesTheConcept() {
        #expect(SealButton.holdDuration == 0.6)
    }
}
