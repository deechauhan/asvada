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
    @State private var selection: AtlasSelection?
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25, longitude: 10),
            span: MKCoordinateSpan(latitudeDelta: 110, longitudeDelta: 200),
        ),
    )

    private let catalog = CountryCatalog.shared

    private var visited: Set<String> {
        AtlasLogic.visitedCodes(items: items)
    }

    var body: some View {
        NavigationStack {
            atlas
                .navigationTitle("Atlas")
                .navigationBarTitleDisplayModeInline()
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
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .onTapGesture(coordinateSpace: .local) { point in
                guard let coordinate = proxy.convert(point, from: .local),
                      let country = AtlasLogic.country(at: coordinate, in: catalog)
                else { return }
                selection = AtlasSelection(code: country.code)
            }
        }
        .overlay(alignment: .top) {
            Headline(text: AtlasLogic.headline(visited: visited.count), isEmpty: visited.isEmpty)
                .padding(.top, Spacing.small)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("atlasMap")
        .sheet(item: $selection) { selection in
            AtlasCountrySheet(code: selection.code, isVisited: visited.contains(selection.code))
                .presentationDetents([.medium, .large])
        }
    }
}

/// The country a tap landed on.
struct AtlasSelection: Identifiable, Equatable {
    let code: String

    var id: String {
        code
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
