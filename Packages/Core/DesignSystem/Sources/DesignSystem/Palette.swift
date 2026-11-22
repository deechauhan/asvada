/// Asvada's colour tokens: warm, calm neutrals with a saffron brand colour.
/// Every text and accent token meets WCAG AA (4.5:1) against every background, in both modes;
/// `DesignSystemTests` enforces this.
public enum Palette {
    // Backgrounds
    public static let background = ColorToken("background", light: "#FAF7F2", dark: "#141210")
    public static let surface = ColorToken("surface", light: "#FFFFFF", dark: "#1E1B18")
    public static let surfaceRaised = ColorToken("surfaceRaised", light: "#F1ECE4", dark: "#2A2622")

    // Text
    public static let textPrimary = ColorToken("textPrimary", light: "#1F1B16", dark: "#F3EEE7")
    public static let textSecondary = ColorToken("textSecondary", light: "#5C554C", dark: "#B5ADA2")

    // Brand
    public static let brand = ColorToken("brand", light: "#A8401C", dark: "#F08A5D")
    /// Text and icons drawn on top of `brand` (e.g. a filled button).
    public static let onBrand = ColorToken("onBrand", light: "#FFFFFF", dark: "#141210")

    // Lines
    public static let separator = ColorToken("separator", light: "#E2DBD0", dark: "#3A352F")

    public static let backgrounds = [background, surface, surfaceRaised]
    public static let text = [textPrimary, textSecondary, brand]
    public static let all = backgrounds + text + [onBrand, separator]
}
