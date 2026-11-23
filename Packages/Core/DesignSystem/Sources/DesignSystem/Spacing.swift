import CoreGraphics

/// Spacing scale (points), based on a 4-pt grid.
public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32

    public static let scale: [(name: String, value: CGFloat)] = [
        ("xxs", xxs), ("xs", xs), ("small", small), ("medium", medium),
        ("large", large), ("xl", xl), ("xxl", xxl),
    ]
}

/// Corner radii. Glass chrome is rounded; keepsakes are nearly square, like real paper.
public enum Radius {
    /// Keepsakes (paper): sharp next to the rounded glass chrome.
    public static let keepsake: CGFloat = 3
    public static let small: CGFloat = 6
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 20
}
