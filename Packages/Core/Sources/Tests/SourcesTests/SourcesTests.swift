import Testing
@testable import Sources

@Test func moduleIsLinked() {
    #expect(SourcesModule.name == "Sources")
}
