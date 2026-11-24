import DesignSystem
import Model
import SwiftData
import SwiftUI

/// Quick-log, step 1: pick which collection you're logging into. The rest of the flow arrives with E6.
struct QuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<ExperienceCollection> { !$0.isHidden },
        sort: [SortDescriptor(\ExperienceCollection.sortIndex), SortDescriptor(\ExperienceCollection.name)],
    )
    private var collections: [ExperienceCollection]

    var body: some View {
        NavigationStack {
            List(collections) { collection in
                Label {
                    Text(collection.name).foregroundStyle(Palette.textPrimary.color)
                } icon: {
                    Image(systemName: collection.icon).foregroundStyle(collection.accent.token.color)
                }
                .accessibilityElement(children: .combine)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle("What did you savour?")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
