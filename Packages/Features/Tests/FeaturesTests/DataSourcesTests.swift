import Foundation
import Testing
@testable import Features

struct DataSourcesTests {
    @Test func everySourceSaysWhatItGivesWhatItSendsAndItsLicence() {
        for source in DataSource.all {
            #expect(!source.provides.isEmpty, "\(source.name) doesn't say what it gives")
            #expect(!source.sends.isEmpty, "\(source.name) doesn't say what it sends")
            #expect(!source.licence.isEmpty, "\(source.name) has no licence")
            #expect(source.link.scheme == "https", "\(source.name) links over plain HTTP")
        }
        #expect(Set(DataSource.all.map(\.id)).count == DataSource.all.count)
    }

    @Test func onlyAppleMapsTMDBAndYourICloudCanBeSentAnything() {
        // The privacy seal promises only searches and map tiles leave the phone (iCloud backup
        // isn't built yet): if a new online source is added, the seal's wording changes with it.
        let online = DataSource.all.filter(\.isOnline).map(\.id)
        #expect(online == ["apple-maps", "tmdb", "icloud"])
        let bundled = DataSource.all.filter { !$0.isOnline }.map(\.id)
        #expect(bundled == ["natural-earth", "openflights"])
    }

    @Test func tmdbIsCreditedInTheWordsItsTermsAskFor() throws {
        let tmdb = try #require(DataSource.all.first { $0.id == "tmdb" })
        #expect(tmdb.licence == "This product uses the TMDB API but is not endorsed or certified by TMDB.")
    }
}
