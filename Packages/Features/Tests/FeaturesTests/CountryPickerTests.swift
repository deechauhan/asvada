import Geo
import Testing
@testable import Features

@MainActor
struct CountryPickerTests {
    @Test func tappingTogglesACountry() {
        let picked = CountryPicker.toggled([], "JP")
        #expect(picked == ["JP"])
        #expect(CountryPicker.toggled(picked, "JP").isEmpty)
        #expect(CountryPicker.toggled(picked, "PT") == ["JP", "PT"])
    }

    @Test func continentHeadersCountWhatsPicked() throws {
        let europe = try #require(CountryCatalog.shared.byContinent[.europe])
        #expect(CountryPicker.picked(in: europe, from: ["PT", "FR", "JP"]) == 2)
    }
}
