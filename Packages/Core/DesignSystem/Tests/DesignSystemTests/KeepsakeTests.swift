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
struct KeepsakeKitTests {
    private static let date = Calendar(identifier: .gregorian).date(
        from: DateComponents(year: 2026, month: 11, day: 23, hour: 8, minute: 5),
    )

    @Test func receiptsPrintDateAndTime() throws {
        let date = try #require(Self.date)
        #expect(KeepsakeDate.withTime(date) == "23·11·26 08:05")
        #expect(KeepsakeDate.short(date) == "23·11·26")
    }

    @Test func barcodesAreStablePerSeedAndDifferAcrossSeeds() {
        let bars = Barcode.widths(for: "entry-1")
        #expect(bars == Barcode.widths(for: "entry-1"))
        #expect(bars != Barcode.widths(for: "entry-2"))
        let inRange = bars.allSatisfy { (1 ... 3).contains($0) }
        #expect(inRange)
    }

    @Test(arguments: [
        (nil, nil),
        (0.0, nil),
        (1.0, "Forgettable"),
        (2.4, "Fine"),
        (3.0, "Good"),
        (4.5, "Unforgettable"),
        (9.0, "Unforgettable"),
    ] as [(Double?, String?)])
    func relishWords(rating: Double?, word: String?) {
        #expect(Relish.word(for: rating) == word)
    }

    @Test func templatesSpeakTheirSummaries() {
        let receipt = Receipt(name: "Prufrock", district: "Clerkenwell", visits: 4, rank: 2)
        #expect(receipt.accessibilitySummary == "Receipt, Prufrock, Clerkenwell, number 2, savoured 4 times")
        #expect(Receipt(name: "Kaffeine").accessibilitySummary == "Receipt, Kaffeine, savoured once")

        let menu = MenuCard(name: "Dishoom", cuisine: "Bombay café", dishes: ["Daal", "Chai"], rank: 1)
        #expect(menu.accessibilitySummary == "Menu card, Dishoom, Bombay café, number 1, Daal and Chai")

        let stub = TicketStub(title: "Perfect Days", year: 2023, relish: "Lovely")
        #expect(stub.accessibilitySummary == "Ticket stub, Perfect Days, 2023, Lovely")
        let rewatched = TicketStub(title: "Past Lives", rewatches: 3)
        #expect(rewatched.accessibilitySummary == "Ticket stub, Past Lives, watched 3 times")

        let pass = BoardingPass(airline: "British Airways", code: "ba", from: "lhr", destination: "hnd", flights: 3)
        #expect(pass.accessibilitySummary == "Boarding pass, British Airways, LHR to HND, 3 flights")
        #expect(BoardingPass(airline: "KLM", code: "KL").accessibilitySummary == "Boarding pass, KLM, 1 flight")

        let postcard = Postcard(city: "Lisbon", country: "Portugal", relish: "Lovely")
        #expect(postcard.accessibilitySummary == "Postcard from Lisbon, Portugal, Lovely")
    }

    @Test func menusPrintAtMostThreeCourses() {
        let menu = MenuCard(name: "Tasting", dishes: ["One", "Two", "Three", "Four"])
        #expect(menu.dishes == ["One", "Two", "Three"])
    }
}

<<<<<<< HEAD
@MainActor
struct ShareCardTests {
    @Test func cardsRenderAt1080By1350() {
        #expect(ShareCard.size.width * ShareCard.scale == 1080)
        #expect(ShareCard.size.height * ShareCard.scale == 1350)
    }

    @Test func passportTitleCountsAndSharesTheWorld() {
        #expect(PassportSpreadCard.title(count: 23, worldTotal: 195) == "23 countries · 12% of the world")
        #expect(PassportSpreadCard.title(count: 1, worldTotal: 195) == "1 country · 1% of the world")
    }

    @Test func topMenuPrintsAtMostFive() {
        let courses = (1 ... 7).map { TopMenuCard.Course(name: "Café \($0)") }
        let card = TopMenuCard(collection: "Cafés", courses: courses)
        #expect(card.courses.count == 5)
        #expect(TopMenuCard.title(collection: "Cafés", count: 5) == "My top 5 cafés")
    }

    @Test func passportSpreadHoldsAtMostTwelveStamps() {
        #expect(PassportSpreadCard.capacity == 12)
    }
}

=======
@MainActor
>>>>>>> feat/114-keepsake-kit-ii
@MainActor
struct SealTests {
    @Test func holdMatchesTheConcept() {
        #expect(SealButton.holdDuration == 0.6)
    }
}
