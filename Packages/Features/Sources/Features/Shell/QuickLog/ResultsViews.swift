import CoreLocation
import DesignSystem
import Geo
import MapKit
import Model
import Sources
import SwiftUI

/// One numbered search result: number, name, then address and distance, year or code. Films show
/// a small poster.
struct FoundRow: View {
    let found: SearchResults.Found
    let onPick: () -> Void

    var body: some View {
        Button(action: onPick) {
            HStack(spacing: Spacing.medium) {
                NumberBadge(number: found.number)
                if case let .film(film) = found.guess.subject {
                    Poster(path: film.posterPath)
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(found.title)
                        .typeToken(.body)
                        .foregroundStyle(Palette.textPrimary.color)
                        .multilineTextAlignment(.leading)
                    if let subtitle = found.subtitle {
                        Text(subtitle)
                            .typeToken(.caption)
                            .foregroundStyle(Palette.textSecondary.color)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.medium)
            .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(found.spokenLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("pick-\(found.title)")
    }
}

/// The plum disc with a result's number, shared by rows and map pins so they read as a pair.
struct NumberBadge: View {
    let number: Int
    var isSelected = false

    var body: some View {
        Text("\(number)")
            .font(.system(.caption, design: .rounded, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Palette.onBrand.color)
            .frame(width: 26, height: 26)
            .background(Palette.brand.color, in: Circle())
            .overlay(Circle().strokeBorder(Palette.onBrand.color, lineWidth: isSelected ? 2 : 0))
            .scaleEffect(isSelected ? 1.25 : 1)
            .accessibilityHidden(true)
    }
}

/// A film's poster at row size, or a plain card while it loads or when there isn't one.
private struct Poster: View {
    let path: String?

    var body: some View {
        Group {
            if let path {
                AsyncImage(url: TMDBClient.posterURL(path, size: "w92")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Palette.surfaceRaised.color
                }
            } else {
                Palette.surfaceRaised.color
            }
        }
        .frame(width: 32, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: Radius.small))
        .accessibilityHidden(true)
    }
}
