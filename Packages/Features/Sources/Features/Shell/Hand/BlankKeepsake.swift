import DesignSystem
import Model
import SwiftUI

extension ExperienceCollection {
    /// What drawing this collection's blank does, spoken and shown: "Savour a café",
    /// "Stamp a country", "Savour in Concerts".
    var savourPhrase: String {
        switch kind {
        case .cafes: "Savour a café"
        case .restaurants: "Savour a restaurant"
        case .countries: "Stamp a country"
        case .cities: "Savour a city"
        case .airlines: "Log a flight"
        case .films: "Savour a film"
        case .custom: "Savour in \(name)"
        }
    }
}

/// A blank keepsake: the collection's card before anything is printed on it, with the
/// collection's ink along the top, its icon, and ruled lines waiting for the print head.
struct BlankKeepsake: View {
    let collection: ExperienceCollection
    /// Whether the thumb is on it (it lifts and its ink deepens).
    var isLifted = false

    static let size = CGSize(width: 64, height: 86)

    private var ink: Color {
        collection.accent.token.color
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Rectangle()
                .fill(ink.opacity(isLifted ? 1 : 0.8))
                .frame(height: 14)
                .overlay {
                    Image(systemName: collection.icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Palette.keepsakePaper.color)
                }
            ForEach(0 ..< 3, id: \.self) { line in
                Capsule()
                    .fill(Palette.textSecondary.color.opacity(0.22))
                    .frame(width: line == 0 ? 40 : 30, height: 2)
            }
            Spacer(minLength: 0)
            Text("ā")
                .font(.system(size: 13, weight: .heavy, design: .serif))
                .foregroundStyle(ink.opacity(0.35))
                .padding(.bottom, Spacing.xs)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(KeepsakePaper(seed: collection.id.uuidString))
        .clipShape(RoundedRectangle(cornerRadius: Radius.keepsake))
        .shadow(color: Palette.textPrimary.color.opacity(isLifted ? 0.3 : 0.16), radius: isLifted ? 10 : 5, y: isLifted ? 6 : 3)
        .accessibilityHidden(true)
    }
}
