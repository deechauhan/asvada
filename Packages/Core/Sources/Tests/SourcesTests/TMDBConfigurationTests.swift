import Testing
@testable import Sources

struct TMDBConfigurationTests {
    @Test func readsKeyFromInfoDictionary() {
        let config = TMDBConfiguration(infoDictionary: ["TMDBAPIKey": "abc123"])
        #expect(config?.apiKey == "abc123")
    }

    @Test func trimsWhitespace() {
        let config = TMDBConfiguration(infoDictionary: ["TMDBAPIKey": "  abc123\n"])
        #expect(config?.apiKey == "abc123")
    }

    @Test func missingKeyIsNil() {
        #expect(TMDBConfiguration(infoDictionary: [:]) == nil)
        #expect(TMDBConfiguration(infoDictionary: nil) == nil)
    }

    @Test func emptyKeyIsNil() {
        #expect(TMDBConfiguration(infoDictionary: ["TMDBAPIKey": ""]) == nil)
    }

    @Test func unexpandedBuildSettingIsNil() {
        #expect(TMDBConfiguration(infoDictionary: ["TMDBAPIKey": "$(TMDB_API_KEY)"]) == nil)
    }
}
