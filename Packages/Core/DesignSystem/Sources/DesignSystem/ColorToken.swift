import SwiftUI
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// A named colour with a light-mode and a dark-mode value.
public struct ColorToken: Sendable, Hashable, Identifiable {
    public let name: String
    public let light: RGBColor
    public let dark: RGBColor

    public var id: String {
        name
    }

    public init(_ name: String, light: String, dark: String) {
        self.name = name
        self.light = RGBColor(hex: light)
        self.dark = RGBColor(hex: dark)
    }

    /// A SwiftUI colour that follows the current light/dark appearance.
    public var color: Color {
        let lightValue = light
        let darkValue = dark
        #if canImport(UIKit)
            return Color(uiColor: UIColor { traits in
                (traits.userInterfaceStyle == .dark ? darkValue : lightValue).uiColor
            })
        #elseif canImport(AppKit)
            return Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return (isDark ? darkValue : lightValue).nsColor
            })
        #endif
    }
}

#if canImport(UIKit)
    extension RGBColor {
        var uiColor: UIColor {
            UIColor(red: red, green: green, blue: blue, alpha: 1)
        }
    }

#elseif canImport(AppKit)
    extension RGBColor {
        var nsColor: NSColor {
            NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
        }
    }
#endif
