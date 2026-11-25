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

/// The same results on a map: numbered plum pins matching the list, things already in the drawer
/// as paper pins, and you. Tap a pin for its name and **This one**.
struct ResultsMap: View {
    let found: [SearchResults.Found]
    /// Things already in the drawer; those with a place get a pin.
    let held: [Item]
    let onPick: (Guess) -> Void
    let onPickHeld: (Item) -> Void

    @State private var position: MapCameraPosition = .automatic
    @State private var selection: Selection?

    private enum Selection: Equatable {
        case found(String)
        case held(UUID)
    }

    private var placedFound: [(found: SearchResults.Found, point: GeoPoint)] {
        found.compactMap { result in result.point.map { (result, $0) } }
    }

    private var placedHeld: [(item: Item, point: GeoPoint)] {
        held.compactMap { item in
            guard let latitude = item.latitude, let longitude = item.longitude else { return nil }
            return (item, GeoPoint(longitude: longitude, latitude: latitude))
        }
    }

    var body: some View {
        VStack(spacing: Spacing.small) {
            Map(position: $position) {
                UserAnnotation()
                ForEach(placedHeld, id: \.item.id) { held in
                    Annotation(held.item.name, coordinate: held.point.coordinate, anchor: .center) {
                        heldPin(held.item)
                    }
                    .annotationTitles(.hidden)
                }
                ForEach(placedFound, id: \.found.id) { placed in
                    Annotation(placed.found.title, coordinate: placed.point.coordinate, anchor: .center) {
                        foundPin(placed.found)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
            .onChange(of: found.map(\.id)) { _, _ in
                selection = nil
                position = .automatic
            }
            .accessibilityIdentifier("resultsMap")
            selectedCard
        }
    }

    private func foundPin(_ result: SearchResults.Found) -> some View {
        Button {
            selection = .found(result.id)
        } label: {
            NumberBadge(number: result.number, isSelected: selection == .found(result.id))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(result.spokenLabel)
        .accessibilityIdentifier("pin-\(result.number)")
    }

    private func heldPin(_ item: Item) -> some View {
        Button {
            selection = .held(item.id)
        } label: {
            Image(systemName: "arrow.uturn.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.brand.color)
                .frame(width: 26, height: 26)
                .background(Palette.keepsakePaper.color, in: Circle())
                .overlay(Circle().strokeBorder(Palette.brand.color, lineWidth: 1.5))
                .scaleEffect(selection == .held(item.id) ? 1.25 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("In your drawer: \(item.name)")
        .accessibilityIdentifier("pin-held-\(item.name)")
    }

    @ViewBuilder
    private var selectedCard: some View {
        switch selection {
        case let .found(id):
            if let result = found.first(where: { $0.id == id }) {
                card(title: result.title, subtitle: result.subtitle) { onPick(result.guess) }
            }
        case let .held(id):
            if let item = held.first(where: { $0.id == id }) {
                card(title: item.name, subtitle: "In your drawer") { onPickHeld(item) }
            }
        case nil:
            Text("Tap a pin to choose it.")
                .typeToken(.caption)
                .foregroundStyle(Palette.textSecondary.color)
        }
    }

    private func card(title: String, subtitle: String?, action: @escaping () -> Void) -> some View {
        HStack(spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Palette.textPrimary.color)
                if let subtitle {
                    Text(subtitle)
                        .typeToken(.caption)
                        .foregroundStyle(Palette.textSecondary.color)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button("This one", action: action)
                .buttonStyle(.borderedProminent)
                .tint(Palette.brand.color)
                .accessibilityIdentifier("mapPick")
        }
        .padding(Spacing.medium)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
    }
}

private extension GeoPoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
