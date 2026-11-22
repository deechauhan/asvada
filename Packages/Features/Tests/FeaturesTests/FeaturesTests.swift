import Testing
@testable import Features

@Test func moduleIsLinked() {
    #expect(FeaturesModule.name == "Features")
}

@Test func linksCoreModules() {
    #expect(FeaturesModule.linkedModules == ["DesignSystem", "Model", "Storage"])
}
