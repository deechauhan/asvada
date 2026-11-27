import Model
import SwiftUI

/// What VoiceOver gets instead of the 3D drum: the drawers as a plain ordered list, each with its
/// stat and the drawer actions.
struct CabinetAccessibleList: View {
    let collections: [ExperienceCollection]
    let actions: CabinetActions

    var body: some View {
        VStack {
            ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                AccessibleDrawer(collection: collection, index: index, actions: actions)
            }
            Button("New collection", action: actions.create)
                .accessibilityIdentifier("newCollectionDrawer")
        }
    }
}

/// One drawer in the VoiceOver list: a button that opens it, with its stat and drawer actions.
private struct AccessibleDrawer: View {
    let collection: ExperienceCollection
    let index: Int
    let actions: CabinetActions

    private var label: String {
        "\(collection.name) drawer"
    }

    private var canShare: Bool {
        ShareContent(collection: collection) != nil
    }

    var body: some View {
        Button(label, action: open)
            .accessibilityValue(collection.drawerSummary.spoken)
            .accessibilityIdentifier("collection-\(collection.kind.rawValue)-\(collection.name)")
            .accessibilityAction(named: "Customise", customise)
            .accessibilityAction(named: "Share", share)
            .accessibilityAction(named: "Move earlier", moveEarlier)
            .accessibilityAction(named: "Move later", moveLater)
            .accessibilityAction(named: "Put away", putAway)
            .accessibilityActions {
                if !collection.anniversaries().isEmpty {
                    Button("On this day") { actions.onThisDay(collection) }
                }
            }
    }

    private func open() {
        actions.open(collection)
    }

    private func customise() {
        actions.customise(collection)
    }

    private func share() {
        if canShare {
            actions.share(collection)
        }
    }

    private func moveEarlier() {
        actions.move(collection, index - 1)
    }

    private func moveLater() {
        actions.move(collection, index + 1)
    }

    private func putAway() {
        actions.hide(collection)
    }
}
