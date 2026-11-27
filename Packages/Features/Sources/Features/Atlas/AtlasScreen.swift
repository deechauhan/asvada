import CoreLocation
import DesignSystem
import Geo
import MapKit
import Model
import SwiftData
import SwiftUI

/// The Atlas (#49): a muted world map with every country you've been to washed in plum ink.
/// Tap a country to see what you've savoured there. Drawn from the bundled outlines, so the
/// ink is there offline; the map underneath is Apple Maps, muted so the ink is the loudest thing.
struct AtlasScreen: View {
    @Query private var items: [Item]
    @Query private var entries: [Entry]
    @State private var store = AtlasFilterStore.shared
    @State private var sheet: AtlasSheet?
    /// What the map shows now; pins appear once it's zoomed in.
    @State private var region: AtlasRegion?
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25, longitude: 10),
            span: MKCoordinateSpan(latitudeDelta: 110, longitudeDelta: 200),
        ),
    )

    private let catalog = CountryCatalog.shared

    /// The countries to ink: the stamped ones, or those the filtered entries were made in.
    private var visited: Set<String> {
        AtlasLogic.inkedCodes(items: items, entries: entries, filter: store.filter)
    }

    /// The places to pin: none while the world is in view.
    private var pins: [Item] {
        guard let region, AtlasLogic.showsPins(latitudeSpan: region.latitudeSpan) else { return [] }
        return AtlasLogic.pins(items: items, in: region, filter: store.filter)
    }

    var body: some View {
        NavigationStack {
            atlas
                .navigationTitle("Atlas")
                .navigationBarTitleDisplayModeInline()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            sheet = .filters
                        } label: {
                            Label(
                                "Filter",
                                systemImage: store.filter.isActive
                                    ? "line.3.horizontal.decrease.circle.fill"
                                    : "line.3.horizontal.decrease.circle",
                            )
                        }
                        .accessibilityValue(AtlasFilterText.buttonValue(count: store.filter.partsOn))
                        .accessibilityIdentifier("atlasFilterButton")
                    }
                }
        }
    }

    private var atlas: some View {
        let visited = visited
        return MapReader { proxy in
            Map(position: $position, interactionModes: [.pan, .zoom]) {
                ForEach(visited.sorted(), id: \.self) { code in
                    if let country = catalog.country(code: code) {
                        ForEach(Array(AtlasLogic.rings(of: country).enumerated()), id: \.offset) { _, ring in
                            MapPolygon(coordinates: ring)
                                .foregroundStyle(Palette.brand.color.opacity(0.55))
                                .stroke(Palette.brand.color, lineWidth: 1)
                        }
                    }
                }
                ForEach(pins, id: \.id) { item in
                    if let latitude = item.latitude, let longitude = item.longitude {
                        Annotation(item.name, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
                            Button {
                                sheet = .place(item.id)
                            } label: {
                                AtlasPinView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                region = AtlasRegion(context.region)
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .onTapGesture(coordinateSpace: .local) { point in
                guard let coordinate = proxy.convert(point, from: .local),
                      let country = AtlasLogic.country(at: coordinate, in: catalog)
                else { return }
                sheet = .country(country.code)
            }
        }
        .overlay(alignment: .top) {
            Headline(
                text: AtlasLogic.headline(visited: visited.count, isFiltered: store.filter.isActive),
                isEmpty: visited.isEmpty,
            )
            .padding(.top, Spacing.small)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("atlasMap")
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case let .country(code):
                AtlasCountrySheet(code: code, isVisited: visited.contains(code), filter: store.filter)
                    .presentationDetents([.medium, .large])
            case .filters:
                AtlasFilterSheet(store: store)
                    .presentationDetents([.medium, .large])
            case let .place(id):
                AtlasPinCard(itemID: id)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

/// What a tap on the map opens: a country's entries, or one place's card.
enum AtlasSheet: Identifiable, Equatable {
    case country(String)
    case place(UUID)
    case filters

    var id: String {
        switch self {
        case .filters: "filters"
        case let .country(code): "country-\(code)"
        case let .place(id): "place-\(id.uuidString)"
        }
    }
}

/// How much of the world is inked, on glass over the top of the map.
private struct Headline: View {
    let text: String
    let isEmpty: Bool

    var body: some View {
        Text(text)
            .font(.system(.title3, design: .serif, weight: .semibold))
            .foregroundStyle(isEmpty ? Palette.textSecondary.color : Palette.brand.color)
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.small)
            .glassEffect(.regular, in: Capsule())
            .contentTransition(.numericText())
            .accessibilityIdentifier("atlasHeadline")
    }
}
