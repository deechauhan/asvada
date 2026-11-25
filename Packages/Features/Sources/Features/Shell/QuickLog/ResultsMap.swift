import CoreLocation
import DesignSystem
import Geo
import MapKit
import Model
import Sources
import SwiftUI

/// Results on a map, and a map to browse (#188, #189): numbered plum pins matching the list,
/// things already in the drawer as paper pins, and you. Apple's own cafés and restaurants can be
/// tapped too, **Search this area** looks again wherever you've panned, and on a map of cities a
/// tap anywhere picks the city there. Whatever's tapped shows its name and **This one**.
struct ResultsMap: View {
    let found: [SearchResults.Found]
    /// Things already in the drawer; those with a place get a pin.
    let held: [Item]
    /// What kind of place the drawer holds, for which map labels can be tapped.
    let kind: PlaceKind?
    let search: any PlaceSearching
    let onPick: (Guess) -> Void
    let onPickHeld: (Item) -> Void
    /// Searches again around the map's centre.
    let onSearchArea: (GeoPoint) -> Void

    @State private var position: MapCameraPosition
    @State private var selection: Selection?
    /// One of Apple's own map labels, tapped.
    @State private var feature: MapFeature?
    /// Where the map is looking now, and where it last searched.
    @State private var visibleCentre: GeoPoint?
    @State private var searchedCentre: GeoPoint?
    @State private var isLookingUp = false

    /// How far the map must move before "Search this area" is offered again, in metres.
    static let searchAgainDistance = 300.0

    init(
        found: [SearchResults.Found],
        held: [Item],
        kind: PlaceKind?,
        start: GeoPoint?,
        search: any PlaceSearching,
        onPick: @escaping (Guess) -> Void,
        onPickHeld: @escaping (Item) -> Void,
        onSearchArea: @escaping (GeoPoint) -> Void,
    ) {
        self.found = found
        self.held = held
        self.kind = kind
        self.search = search
        self.onPick = onPick
        self.onPickHeld = onPickHeld
        self.onSearchArea = onSearchArea
        // With results, fit them; with nothing yet, start where you are (or last savoured).
        if found.isEmpty, let start {
            let span = kind == .city ? 400_000.0 : 1500
            _position = State(initialValue: .region(MKCoordinateRegion(
                center: start.coordinate,
                latitudinalMeters: span,
                longitudinalMeters: span,
            )))
        } else {
            _position = State(initialValue: .automatic)
        }
        _searchedCentre = State(initialValue: found.isEmpty ? nil : start)
    }

    private enum Selection: Equatable {
        case found(String)
        case held(UUID)
        case place(PlaceResult)
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

    /// Whether to offer "Search this area": nothing searched yet, or the map has moved on.
    private var offersSearchHere: Bool {
        guard let searchedCentre else { return true }
        guard let visibleCentre else { return false }
        return SearchResults.metres(from: searchedCentre, to: visibleCentre) > Self.searchAgainDistance
    }

    /// Apple's own labels for the drawer's kind of place (none on a map of cities).
    private var pointsOfInterest: PointOfInterestCategories {
        guard let kind, kind != .city else { return .excludingAll }
        guard let categories = kind.categories else { return .all }
        return .including(categories)
    }

    var body: some View {
        VStack(spacing: Spacing.small) {
            MapReader { proxy in
                map
                    .onTapGesture { screen in
                        // Cities: a tap anywhere picks the city there.
                        guard kind == .city, let coordinate = proxy.convert(screen, from: .local) else { return }
                        lookUpCity(at: GeoPoint(longitude: coordinate.longitude, latitude: coordinate.latitude))
                    }
            }
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
            .overlay(alignment: .top) { searchHereButton }
            .accessibilityIdentifier("resultsMap")
            selectedCard
        }
        .onChange(of: found.map(\.id)) { _, _ in
            selection = nil
            if !found.isEmpty {
                position = .automatic
            }
        }
        .onChange(of: feature) { _, tapped in
            if let tapped {
                lookUp(tapped)
            }
        }
    }

    private var map: some View {
        Map(position: $position, selection: $feature) {
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
        .mapStyle(.standard(pointsOfInterest: pointsOfInterest))
        .mapFeatureSelectionDisabled { feature in kind == .city || feature.kind != .pointOfInterest }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleCentre = GeoPoint(longitude: context.region.center.longitude, latitude: context.region.center.latitude)
        }
    }

    @ViewBuilder
    private var searchHereButton: some View {
        if offersSearchHere, kind != .city || !found.isEmpty {
            Button("Search this area", systemImage: "magnifyingglass") {
                let centre = visibleCentre ?? searchedCentre ?? GeoPoint(longitude: 0, latitude: 30)
                searchedCentre = centre
                onSearchArea(centre)
            }
            .font(.callout.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(Palette.brand.color)
            .padding(.top, Spacing.small)
            .accessibilityIdentifier("searchThisArea")
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

    /// Turns a tapped map label into a place to keep.
    private func lookUp(_ tapped: MapFeature) {
        isLookingUp = true
        Task {
            defer { isLookingUp = false }
            guard let item = try? await MKMapItemRequest(feature: tapped).mapItem,
                  let place = PlaceResult(mapItem: item)
            else { return }
            selection = .place(place)
        }
    }

    private func lookUpCity(at point: GeoPoint) {
        isLookingUp = true
        Task {
            defer { isLookingUp = false }
            if let city = try? await search.city(at: point) {
                selection = .place(city)
            }
        }
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
        case let .place(place):
            card(title: place.name, subtitle: place.address) {
                onPick(Guess(id: place.externalRef, title: place.name, source: .typed, subject: .place(place)))
            }
        case nil:
            Text(isLookingUp ? "Looking it up…" : hint)
                .typeToken(.caption)
                .foregroundStyle(Palette.textSecondary.color)
        }
    }

    private var hint: String {
        kind == .city ? "Tap a city, or a pin, to choose it." : "Tap a pin or a place on the map to choose it."
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
