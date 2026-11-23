import SwiftUI

/// Type tokens v2 (docs/design/CONCEPT.md §9). All are built on Dynamic Type text styles so
/// they scale with the user's setting. New York (`.serif`) carries the voice; SF Pro the UI;
/// SF Mono the codes and dates printed on keepsakes.
public enum TypeToken: String, CaseIterable, Sendable, Identifiable {
    /// "No. 1", "23 countries": New York Heavy.
    case hero
    /// Screen titles: New York Bold.
    case display
    /// Month headers in the Journal: New York Italic.
    case masthead
    /// Card titles and item names: New York Semibold.
    case title
    /// Prompts, notes and relish words: New York Italic.
    case voice
    case headline
    case body
    case callout
    case caption
    /// ADMIT ONE, GATE, ENTRY: SF Pro Expanded, uppercase, tracked.
    case ticketLabel
    /// IATA codes and printed dates: SF Mono.
    case code

    public var id: String {
        rawValue
    }

    public var textStyle: Font.TextStyle {
        switch self {
        case .hero, .display, .masthead: .largeTitle
        case .title: .title2
        case .voice: .title3
        case .headline: .headline
        case .body, .code: .body
        case .callout: .callout
        case .caption: .caption
        case .ticketLabel: .caption2
        }
    }

    public var design: Font.Design {
        switch self {
        case .hero, .display, .masthead, .title, .voice: .serif
        case .code: .monospaced
        default: .default
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .hero: .heavy
        case .display: .bold
        case .title, .headline, .ticketLabel: .semibold
        case .code: .medium
        default: .regular
        }
    }

    public var isItalic: Bool {
        self == .masthead || self == .voice
    }

    /// Letter spacing in points (ticket labels are tracked out).
    public var tracking: CGFloat {
        self == .ticketLabel ? 1.5 : 0
    }

    public var isUppercase: Bool {
        self == .ticketLabel
    }

    public var font: Font {
        var font = Font.system(textStyle, design: design, weight: weight)
        if isItalic {
            font = font.italic()
        }
        if self == .ticketLabel {
            font = font.width(.expanded)
        }
        return font
    }
}

/// Applies a type token's font, tracking and case.
struct TypeTokenModifier: ViewModifier {
    let token: TypeToken

    func body(content: Content) -> some View {
        content
            .font(token.font)
            .tracking(token.tracking)
            .textCase(token.isUppercase ? .uppercase : nil)
    }
}

public extension View {
    /// Applies a type token's font, tracking and case.
    func typeToken(_ token: TypeToken) -> some View {
        modifier(TypeTokenModifier(token: token))
    }
}
