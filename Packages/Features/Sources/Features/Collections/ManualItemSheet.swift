import DesignSystem
import Geo
import MapKit
import Model
import Storage
import SwiftUI

extension ExperienceCollection {
    /// Whether things in this collection have a place worth pinning: places found on the map,
    /// and custom collections (anything goes). Films, airlines and countries don't.
    var takesLocation: Bool {
        switch itemSource {
        case .mapkit, .manual: true
        case .tmdb, .airlineCatalog, .countryCatalog: false
        }
    }

    /// Where the newest pinned thing in this collection is, to start the pin map there.
    var lastPinnedPoint: GeoPoint? {
        let pinned = (items ?? []).filter { $0.latitude != nil && $0.longitude != nil }
        guard let newest = pinned.max(by: { $0.createdAt < $1.createdAt }),
              let latitude = newest.latitude, let longitude = newest.longitude
        else { return nil }
        return GeoPoint(longitude: longitude, latitude: latitude)
    }
}

/// "Add by hand", for when search can't find it: a name, and for places an optional pin
/// dropped on a map. The item then behaves like one found by search (its pin stamps its
/// country when it's logged).
struct ManualItemSheet: View {
    let collection: ExperienceCollection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var draft = ManualItemDraft()
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .accessibilityIdentifier("manualItemName")
                } footer: {
                    Text("Write it in by hand when search can't find it.")
                }
                if collection.takesLocation {
                    Section {
                        PinMap(pin: $draft.location, start: collection.lastPinnedPoint, tint: collection.accent.token.color)
                            .frame(height: 240)
                            .listRowInsets(EdgeInsets())
                        PinSummary(draft: draft) { draft.location = nil }
                    } header: {
                        Text("Where (optional)")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle("Add to \(collection.name)")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(!draft.isValid)
                        .accessibilityIdentifier("manualItemSave")
                }
            }
            .onAppear { nameFocused = true }
        }
    }

    private func add() {
        do {
            try Repository(context: context).addManualItem(draft, in: collection)
            dismiss()
        } catch {
            assertionFailure("Adding a manual item failed: \(error)")
        }
    }
}

/// A map to drop a pin on: tap anywhere to put it there, tap again to move it.
private struct PinMap: View {
    @Binding var pin: GeoPoint?
    let tint: Color
    @State private var camera: MapCameraPosition

    init(pin: Binding<GeoPoint?>, start: GeoPoint?, tint: Color) {
        _pin = pin
        self.tint = tint
        let centre = start ?? GeoPoint(longitude: 0, latitude: 30)
        let span = start == nil ? 120.0 : 0.05
        _camera = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centre.latitude, longitude: centre.longitude),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span),
        )))
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                if let pin {
                    Marker("Here", coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude))
                        .tint(tint)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                pin = GeoPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map")
        .accessibilityHint("Tap to drop a pin where it is")
        .accessibilityIdentifier("manualItemMap")
    }
}

/// Under the map: where the pin is (its country, or the coordinates at sea), or how to drop one.
struct PinSummary: View {
    let draft: ManualItemDraft
    let clear: () -> Void

    var body: some View {
        HStack {
            Text(Self.summary(for: draft))
                .typeToken(.callout)
                .foregroundStyle(draft.location == nil ? Palette.textSecondary.color : Palette.textPrimary.color)
                .accessibilityIdentifier("manualItemPin")
            Spacer(minLength: Spacing.small)
            if draft.location != nil {
                Button("Clear", role: .destructive, action: clear)
                    .accessibilityIdentifier("manualItemClearPin")
            }
        }
    }

    /// "Pinned in Portugal", "Pinned at 30.00, -30.00" at sea, or the hint before a pin.
    static func summary(for draft: ManualItemDraft) -> String {
        guard let location = draft.location else { return "Tap the map to pin where it is" }
        if let country = draft.country {
            return "Pinned in \(country.name)"
        }
        return String(format: "Pinned at %.2f, %.2f", location.latitude, location.longitude)
    }
}
