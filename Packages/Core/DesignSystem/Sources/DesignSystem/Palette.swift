/// Asvada's colour tokens, v2 "Aubergine & Saffron" (docs/design/CONCEPT.md §9).
///
/// Plum is the ink (seals, ranks, visited countries, primary actions); saffron is the spark
/// (macron bars, glints) and is **decorative only** as a fill: use `saffronInk` for saffron text.
/// Every text and accent token meets WCAG AA (4.5:1) against every background, in both modes;
/// `DesignSystemTests` enforces this.
public enum Palette {
    // MARK: - Backgrounds

    /// Warm paper: the app background.
    public static let background = ColorToken("background", light: "#FAF6F0", dark: "#15101A")
    /// Grouped rows and sheets.
    public static let surface = ColorToken("surface", light: "#FFFFFF", dark: "#1F1826")
    /// Chips and fields.
    public static let surfaceRaised = ColorToken("surfaceRaised", light: "#F1EAF0", dark: "#2B2233")
    /// The fill of every keepsake.
    public static let keepsakePaper = ColorToken("keepsakePaper", light: "#FFFBF4", dark: "#241C2B")
    /// Selected states and visited tints behind text.
    public static let plumWash = ColorToken("plumWash", light: "#EFE3F5", dark: "#2F2140")
    /// Highlights and the "No. 1" badge field.
    public static let saffronWash = ColorToken("saffronWash", light: "#FBEBD0", dark: "#33261A")

    // MARK: - Text

    /// Ink: body text and titles.
    public static let textPrimary = ColorToken("textPrimary", light: "#221530", dark: "#F4EEF6")
    /// Captions and metadata.
    public static let textSecondary = ColorToken("textSecondary", light: "#5D4E68", dark: "#BBAFC4")

    // MARK: - Brand

    /// Plum ink (lilac in dark mode).
    public static let brand = ColorToken("brand", light: "#6B2D8C", dark: "#C9A3EC")
    /// Text and icons drawn on top of `brand`.
    public static let onBrand = ColorToken("onBrand", light: "#FFFFFF", dark: "#15101A")
    /// Saffron fill for macron bars and glints. Never use it as text on paper (1.9:1).
    public static let saffron = ColorToken("saffron", light: "#F2A93B", dark: "#F5B54A")
    /// Saffron-coloured text.
    public static let saffronInk = ColorToken("saffronInk", light: "#8C4F00", dark: "#F5B54A")
    /// Text drawn on top of `saffron`.
    public static let onSaffron = ColorToken("onSaffron", light: "#221530", dark: "#15101A")

    // MARK: - Hero field

    /// Top of the aubergine hero gradient (icon, onboarding, share cards). Same in both modes.
    public static let aubergineTop = ColorToken("aubergineTop", light: "#3A1748", dark: "#3A1748")
    /// Bottom of the aubergine hero gradient.
    public static let aubergineBottom = ColorToken("aubergineBottom", light: "#24102E", dark: "#24102E")
    /// Text on the aubergine field.
    public static let onAubergine = ColorToken("onAubergine", light: "#FAF6F0", dark: "#FAF6F0")

    // MARK: - Lines

    public static let separator = ColorToken("separator", light: "#E4DAE3", dark: "#3A3042")

    public static let backgrounds = [background, surface, surfaceRaised, keepsakePaper, plumWash, saffronWash]
    public static let text = [textPrimary, textSecondary, brand, saffronInk]
    public static let hero = [aubergineTop, aubergineBottom]
    public static let all = backgrounds + text + [onBrand, saffron, onSaffron] + hero + [onAubergine, separator]
}
