import Testing
@testable import Features

struct PrivacyTests {
    @Test func thePrivacyPageSplitsTheSourcesByWhetherAnythingIsSent() {
        let online = Set(DataSource.all.filter(\.isOnline).map(\.id))
        let bundled = Set(DataSource.all.filter { !$0.isOnline }.map(\.id))
        #expect(online.isSuperset(of: ["apple-maps", "tmdb"]))
        #expect(bundled.isSuperset(of: ["natural-earth", "openflights"]))
        #expect(online.isDisjoint(with: bundled))
        #expect(online.union(bundled).count == DataSource.all.count)
    }
}
