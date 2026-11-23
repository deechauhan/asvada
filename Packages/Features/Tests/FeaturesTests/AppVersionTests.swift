import Testing
@testable import Features

struct AppVersionTests {
    @Test func readsVersionAndBuild() {
        let version = AppVersion(infoDictionary: ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "42"])
        #expect(version.version == "0.1.0")
        #expect(version.build == "42")
        #expect(version.displayString == "Version 0.1.0 (42)")
    }

    @Test func fallsBackWhenMissing() {
        let version = AppVersion(infoDictionary: nil)
        #expect(version.displayString == "Version 0.0.0 (0)")
    }
}
