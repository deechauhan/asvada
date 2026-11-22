import SwiftUI

/// Type tokens. All are built on Dynamic Type text styles so they scale with the user's setting.
public enum TypeToken: String, CaseIterable, Sendable, Identifiable {
    case display
    case title
    case headline
    case body
    case callout
    case caption

    public var id: String {
        rawValue
    }

    public var textStyle: Font.TextStyle {
        switch self {
        case .display: .largeTitle
        case .title: .title2
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .caption: .caption
        }
    }

    /// Serif for display and titles gives a warm, journal-like feel; UI text stays in SF Pro.
    public var design: Font.Design {
        switch self {
        case .display, .title: .serif
        default: .default
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .display: .bold
        case .title, .headline: .semibold
        default: .regular
        }
    }

    public var font: Font {
        .system(textStyle, design: design, weight: weight)
    }
}

public extension View {
    /// Applies a type token's font.
    func typeToken(_ token: TypeToken) -> some View {
        font(token.font)
    }
}
