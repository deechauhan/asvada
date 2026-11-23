import DesignSystem
import Model
import Storage
import SwiftUI

/// "Now, one thing you loved." Pick café, film or airline; the keepsake is pre-filled and you
/// make it yours with Hold to Savour. It lands in the Journal.
struct FirstKeepsakeStep: View {
    enum Choice: String, CaseIterable, Identifiable {
        case cafe = "A café"
        case film = "A film"
        case airline = "An airline"

        var id: String {
            rawValue
        }

        var kind: CollectionKind {
            switch self {
            case .cafe: .cafes
            case .film: .films
            case .airline: .airlines
            }
        }

        /// What the keepsake says until you type your own.
        var suggestion: String {
            switch self {
            case .cafe: "My favourite café"
            case .film: "The last film I loved"
            case .airline: "My favourite airline"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @State private var choice = Choice.cafe
    @State private var name = ""
    @State private var isSealed = false
    let onDone: () -> Void

    private var title: String {
        name.isEmpty ? choice.suggestion : name
    }

    var body: some View {
        OnboardingPage(title: "Now, one thing you loved", action: "Done", onContinue: onDone) {
            Picker("Kind", selection: $choice) {
                ForEach(Choice.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("firstKeepsakeKind")
            TextField(choice.suggestion, text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("firstKeepsakeName")
            preview
                .overlay(alignment: .bottomTrailing) {
                    if isSealed {
                        WaxSeal().padding(Spacing.small)
                    }
                }
                .frame(maxWidth: .infinity)
            VStack(spacing: Spacing.small) {
                SealButton(action: seal)
                Text(isSealed ? "Savoured. It's in your Journal." : "Hold to savour")
                    .typeToken(.voice)
                    .foregroundStyle(Palette.textSecondary.color)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch choice {
        case .cafe:
            Receipt(name: title, date: .now, visits: 1)
        case .film:
            TicketStub(title: title, date: .now)
        case .airline:
            BoardingPass(airline: title, code: String(title.prefix(2)).uppercased(), date: .now)
        }
    }

    private func seal() {
        guard !isSealed else { return }
        do {
            try OnboardingStore.savour(title, kind: choice.kind, in: Repository(context: context))
            isSealed = true
        } catch {
            assertionFailure("Saving the first keepsake failed: \(error)")
        }
    }
}
