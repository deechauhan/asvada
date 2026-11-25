import Foundation
import Geo
import Model
import Sources
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct PrintHeadTests {
    private func guess(_ title: String, _ source: GuessSource = .again) -> Guess {
        Guess(id: title, title: title, source: source, subject: .item(Item(name: title)))
    }

    @Test func itPrintsTheFirstGuessAndCountsThem() {
        let head = PrintHead(guesses: [guess("Prufrock"), guess("Monmouth"), guess("Kaffeine")])
        #expect(head.current?.title == "Prufrock")
        #expect(head.sourceLine == "Again? · 1 of 3")
        #expect(PrintHead(guesses: [guess("Japan", .youreIn)]).sourceLine == "You're in")
        #expect(PrintHead().sourceLine == nil)
    }

    @Test func tearingPrintsTheNextAndSwipingBackRestores() {
        var head = PrintHead(guesses: [guess("Prufrock"), guess("Monmouth")])
        #expect(!head.canRestore)
        #expect(head.tear())
        #expect(head.current?.title == "Monmouth")
        #expect(head.sourceLine == "Again? · 2 of 2")
        #expect(head.restore())
        #expect(head.current?.title == "Prufrock")
        // Tearing the last guess leaves the blank empty, ready to type.
        head.tear()
        head.tear()
        #expect(head.current == nil)
        #expect(!head.tear())
    }

    @Test func laterGuessesJoinTheEndWithoutRepeats() {
        var head = PrintHead(guesses: [guess("Japan")])
        head.append([guess("Japan"), guess("Kyoto", .nearYou)])
        #expect(head.guesses.map(\.title) == ["Japan", "Kyoto"])
    }

    @Test func aSidewaysSwipeTearsAtNinetyPointsOrSixHundredFiftyAPerSecond() {
        #expect(PrintHead.swipe(translation: -90, velocity: 0) == .tear)
        #expect(PrintHead.swipe(translation: -20, velocity: -700) == .tear)
        #expect(PrintHead.swipe(translation: 95, velocity: 0) == .restore)
        #expect(PrintHead.swipe(translation: -60, velocity: -300) == .none)
    }

    @Test func itPrintsACharacterEveryTwentyMilliseconds() {
        #expect(PrintHead.printed("Prufrock", after: 0) == "")
        #expect(PrintHead.printed("Prufrock", after: 0.061) == "Pru")
        #expect(PrintHead.printed("Prufrock", after: 5) == "Prufrock")
    }

    @Test func againGuessesTheLastThingsSavouredInTheDrawer() throws {
        let container = try AsvadaStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let cafes = try #require(try repository.collections().first { $0.kind == .cafes })
        let never = try repository.addManualItem(ManualItemDraft(name: "Never been"), in: cafes)
        let old = try repository.addManualItem(ManualItemDraft(name: "Old haunt"), in: cafes)
        let new = try repository.addManualItem(ManualItemDraft(name: "New place"), in: cafes)
        repository.addEntry(to: old, date: .now.addingTimeInterval(-86400))
        repository.addEntry(to: new)
        #expect(Guesses.again(in: cafes).map(\.title) == ["New place", "Old haunt"])
        #expect(!Guesses.again(in: cafes).contains { $0.title == never.name })
    }

    @Test func youreInGuessesTheCountryForCountriesOnly() {
        let countries = ExperienceCollection(name: "Countries", kind: .countries, itemSource: .countryCatalog)
        let cafes = ExperienceCollection(name: "Cafés", kind: .cafes, itemSource: .mapkit)
        let lisbon = GeoPoint(longitude: -9.14, latitude: 38.71)
        #expect(Guesses.youreIn(at: lisbon, in: countries).map(\.title) == ["Portugal"])
        #expect(Guesses.youreIn(at: lisbon, in: cafes).isEmpty)
    }

    @Test func typingPrintsTheCataloguesTopResult() async {
        let countries = ExperienceCollection(name: "Countries", kind: .countries, itemSource: .countryCatalog)
        let airlines = ExperienceCollection(name: "Airlines", kind: .airlines, itemSource: .airlineCatalog)
        let tmdb = TMDBClient(configuration: nil)
        let country = await Guesses.top(for: "japa", in: countries, near: nil, search: MapKitPlaceSearch(), tmdb: tmdb)
        #expect(country?.title == "Japan")
        #expect(country?.source == .typed)
        let airline = await Guesses.top(for: "British", in: airlines, near: nil, search: MapKitPlaceSearch(), tmdb: tmdb)
        #expect(airline?.title.contains("British") == true)
        #expect(await Guesses.top(for: "  ", in: countries, near: nil, search: MapKitPlaceSearch(), tmdb: tmdb) == nil)
    }

    @Test func acceptingAGuessAddsItToTheDrawerOnce() throws {
        let container = try AsvadaStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let countries = try #require(try repository.collections().first { $0.kind == .countries })
        let japan = try #require(CountryCatalog.shared.country(code: "JP"))
        let guess = Guess(id: "iso:JP", title: "Japan", source: .youreIn, subject: .country(japan))
        let first = Guesses.accept(guess, in: countries, repository: repository)
        let second = Guesses.accept(guess, in: countries, repository: repository)
        #expect(first.id == second.id)
        #expect(first.countryCode == "JP")
        #expect(first.externalRef == "iso:JP")
    }
}
