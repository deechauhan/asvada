import Testing
@testable import DesignSystem

@Test func moduleIsLinked() {
    #expect(DesignSystemModule.name == "DesignSystem")
}

struct ContrastTests {
    @Test func blackOnWhiteIsTwentyOne() {
        let ratio = RGBColor(hex: "#000000").contrastRatio(with: RGBColor(hex: "#FFFFFF"))
        #expect(abs(ratio - 21) < 0.001)
    }

    @Test func contrastIsSymmetric() {
        let first = RGBColor(hex: "#A8401C")
        let second = RGBColor(hex: "#FAF7F2")
        #expect(first.contrastRatio(with: second) == second.contrastRatio(with: first))
    }

    @Test func hexRoundTrips() {
        #expect(RGBColor(hex: "#8a5a2b").hexString == "#8A5A2B")
        #expect(RGBColor(hex: "1F1B16").hexString == "#1F1B16")
    }

    @Test(arguments: Palette.text + CollectionAccent.allCases.map(\.token))
    func textMeetsWCAGAAOnEveryBackground(token: ColorToken) {
        for background in Palette.backgrounds {
            let light = token.light.contrastRatio(with: background.light)
            let dark = token.dark.contrastRatio(with: background.dark)
            #expect(light >= 4.5, "\(token.name) on \(background.name) (light) is \(light)")
            #expect(dark >= 4.5, "\(token.name) on \(background.name) (dark) is \(dark)")
        }
    }

    @Test func onBrandMeetsWCAGAA() {
        #expect(Palette.onBrand.light.contrastRatio(with: Palette.brand.light) >= 4.5)
        #expect(Palette.onBrand.dark.contrastRatio(with: Palette.brand.dark) >= 4.5)
    }

    @Test func onSaffronMeetsWCAGAA() {
        #expect(Palette.onSaffron.light.contrastRatio(with: Palette.saffron.light) >= 4.5)
        #expect(Palette.onSaffron.dark.contrastRatio(with: Palette.saffron.dark) >= 4.5)
    }

    @Test(arguments: [Palette.onAubergine, Palette.saffron, Palette.brand])
    func heroTextMeetsWCAGAAOnAubergine(token: ColorToken) {
        for field in Palette.hero {
            let ratio = token.dark.contrastRatio(with: field.dark)
            #expect(ratio >= 4.5, "\(token.name) on \(field.name) is \(ratio)")
        }
    }

    /// Saffron fill is decorative: it must stay out of the text tokens.
    @Test func saffronFillIsNotATextToken() {
        #expect(!Palette.text.contains(Palette.saffron))
        #expect(Palette.saffron.light.contrastRatio(with: Palette.background.light) < 4.5)
    }
}

struct TokenTests {
    @Test func tokenNamesAreUnique() {
        let names = (Palette.all + CollectionAccent.allCases.map(\.token)).map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test func everyCollectionHasDistinctAccent() {
        let lights = CollectionAccent.allCases.map(\.token.light)
        #expect(Set(lights).count == lights.count)
    }

    @Test func spacingScaleIncreases() {
        let values = Spacing.scale.map(\.value)
        #expect(values == values.sorted())
        #expect(values.allSatisfy { $0.truncatingRemainder(dividingBy: 2) == 0 })
    }

    @Test func voiceTokensUseNewYork() {
        for token in [TypeToken.hero, .display, .masthead, .title, .voice] {
            #expect(token.design == .serif, "\(token) should be serif")
        }
        #expect(TypeToken.body.design == .default)
        #expect(TypeToken.code.design == .monospaced)
    }

    @Test func italicsAndTicketLabels() {
        #expect(TypeToken.masthead.isItalic && TypeToken.voice.isItalic)
        #expect(!TypeToken.display.isItalic)
        #expect(TypeToken.ticketLabel.isUppercase && TypeToken.ticketLabel.tracking > 0)
    }
}
