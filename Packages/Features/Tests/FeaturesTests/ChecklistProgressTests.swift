import Geo
import Testing
@testable import Features

struct ChecklistProgressTests {
    @Test func nothingStampedSaysSoInsteadOfZero() {
        let none = ChecklistProgress(stamped: [])
        #expect(none.stamped == 0)
        #expect(none.percent == 0)
        #expect(none.headline == "Not one stamp yet")
        #expect(none.spoken == "No countries stamped yet")
    }

    @Test func theWorldIsCountedAgainst195() {
        let some = ChecklistProgress(stamped: ["JP", "PT", "BR"])
        #expect(some.stamped == 3)
        #expect(some.total == 195)
        #expect(some.percent == 2)
        #expect(some.headline == "3 · 2%")
        #expect(some.spoken == "3 of 195 countries, 2 percent")
        // One country is never rounded down to 0%.
        #expect(ChecklistProgress(stamped: ["JP"]).percent == 1)
    }

    @Test func eachContinentCountsItsOwnStamps() throws {
        let progress = ChecklistProgress(stamped: ["JP", "PT", "ES", "BR"])
        let europe = try #require(progress.continents.first { $0.continent == .europe })
        #expect(europe.stamped == 2)
        #expect(europe.total == CountryCatalog.shared.byContinent[.europe]?.count)
        #expect(europe.spoken == "Europe, 2 of \(europe.total)")
        let asia = try #require(progress.continents.first { $0.continent == .asia })
        #expect(asia.stamped == 1)
        // Every continent with places is listed, in a stable order.
        let withPlaces = Continent.allCases.filter { CountryCatalog.shared.byContinent[$0] != nil }
        #expect(progress.continents.map(\.continent) == withPlaces)
    }

    @Test func unknownCodesDontCount() {
        #expect(ChecklistProgress(stamped: ["ZZ", "JP"]).stamped == 1)
    }
}
