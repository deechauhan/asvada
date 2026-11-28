import DesignSystem
import Model
import SwiftData
import SwiftUI

/// The Atlas's filters (#52): which collections, which years, and one trip. Changes apply as you
/// make them, so the map behind the sheet follows; Reset puts everything back.
struct AtlasFilterSheet: View {
    @Bindable var store: AtlasFilterStore
    @Query(sort: \ExperienceCollection.sortIndex) private var collections: [ExperienceCollection]
    @Query(sort: \Trip.start, order: .reverse) private var trips: [Trip]
    @Query private var entries: [Entry]
    @Environment(\.dismiss) private var dismiss

    private var years: [Int] {
        AtlasLogic.years(of: entries)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Up top, where the half-height sheet shows it without scrolling.
                Section {
                    HStack {
                        Text(AtlasFilterText.footer(count: store.filter.partsOn))
                            .typeToken(.callout)
                            .foregroundStyle(Palette.textSecondary.color)
                            .accessibilityIdentifier("atlasFilterStatus")
                        Spacer()
                        Button("Reset") {
                            store.filter = AtlasFilter()
                        }
                        .buttonStyle(.borderless)
                        .disabled(!store.filter.isActive)
                        .accessibilityIdentifier("atlasFilterReset")
                    }
                }
                Section("Collections") {
                    ForEach(collections.filter { !$0.isHidden }) { collection in
                        Button {
                            store.filter.toggle(collection: collection.id)
                        } label: {
                            HStack {
                                Label {
                                    Text(collection.name)
                                        .foregroundStyle(Palette.textPrimary.color)
                                } icon: {
                                    Image(systemName: collection.icon)
                                        .foregroundStyle(collection.accent.token.color)
                                }
                                Spacer()
                                if store.filter.collections.contains(collection.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Palette.brand.color)
                                }
                            }
                        }
                        .accessibilityAddTraits(store.filter.collections.contains(collection.id) ? .isSelected : [])
                        .accessibilityIdentifier("atlasFilterCollection-\(collection.name)")
                    }
                }
                Section("Years") {
                    Picker("From", selection: firstYear) {
                        Text("Any year").tag(Int?.none)
                        ForEach(years, id: \.self) { year in
                            Text(String(year)).tag(Int?.some(year))
                        }
                    }
                    .accessibilityIdentifier("atlasFilterFrom")
                    Picker("To", selection: lastYear) {
                        Text("Any year").tag(Int?.none)
                        ForEach(years, id: \.self) { year in
                            Text(String(year)).tag(Int?.some(year))
                        }
                    }
                    .accessibilityIdentifier("atlasFilterTo")
                }
                Section("Trip") {
                    Picker("Trip", selection: $store.filter.trip) {
                        Text("Any trip").tag(UUID?.none)
                        ForEach(trips) { trip in
                            Text(trip.name).tag(UUID?.some(trip.id))
                        }
                    }
                    .accessibilityIdentifier("atlasFilterTrip")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle("Filter the map")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("atlasFilterDone")
                }
            }
        }
        .accessibilityIdentifier("atlasFilterSheet")
    }

    private var firstYear: Binding<Int?> {
        Binding(get: { store.filter.fromYear }, set: { store.filter.setFromYear($0) })
    }

    private var lastYear: Binding<Int?> {
        Binding(get: { store.filter.toYear }, set: { store.filter.setToYear($0) })
    }
}

/// The words the filter sheet and its button use.
enum AtlasFilterText {
    /// "Showing everything" / "1 filter on" / "3 filters on".
    static func footer(count: Int) -> String {
        switch count {
        case 0: "Showing everything."
        case 1: "1 filter on."
        default: "\(count) filters on."
        }
    }

    /// What VoiceOver says for the toolbar button.
    static func buttonValue(count: Int) -> String {
        count == 0 ? "Off" : footer(count: count)
    }
}
