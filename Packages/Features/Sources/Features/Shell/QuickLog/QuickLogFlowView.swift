import DesignSystem
import Model
import Ranking
import Storage
import SwiftData
import SwiftUI

/// Quick-log after a blank is drawn (INTERACTION.md §5): say what it was, savour it the way its
/// collection rates things, then hold the ā to seal. The print head (#154) will print guesses
/// onto the blank; until then the name is typed, matching what's already in the drawer.
struct QuickLogFlowView: View {
    let collection: ExperienceCollection
    let startedAt: Date
    /// The toast's words and the new entry, once sealed.
    let onSealed: (String, UUID) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage: Stage
    @State private var item: Item?
    @State private var savouring = Savouring()

    enum Stage: Equatable {
        case pick
        case savour(SavourStep)
        case seal
    }

    /// - Parameter again: an item to savour again: it skips straight to sealing.
    init(
        collection: ExperienceCollection,
        again: Item? = nil,
        startedAt: Date,
        onSealed: @escaping (String, UUID) -> Void,
    ) {
        self.collection = collection
        self.startedAt = startedAt
        self.onSealed = onSealed
        _item = State(initialValue: again)
        _stage = State(initialValue: again == nil ? .pick : .seal)
        let lastRating = again?.entries?.max { $0.date < $1.date }?.rating
        _savouring = State(initialValue: Savouring(rating: lastRating))
    }

    private var repository: Repository {
        Repository(context: context)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                // While picking, the print head shows the blank with its guess printed on it.
                if stage != .pick {
                    BlankKeepsake(collection: collection, isLifted: true)
                        .scaleEffect(1.6)
                        .frame(width: BlankKeepsake.size.width * 1.6, height: BlankKeepsake.size.height * 1.6)
                        .padding(.top, Spacing.large)
                }
                if let item {
                    Text(item.name)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary.color)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("quickLogItem")
                }
                stageView
            }
            .padding(.horizontal, Spacing.large)
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: .infinity)
            // The blank itself is decoration; the drawn flow is the container VoiceOver and tests find.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("drawnBlank")
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(Motion.animation(Motion.settle, reduceMotion: reduceMotion), value: stage)
    }

    @ViewBuilder
    private var stageView: some View {
        switch stage {
        case .pick:
            PickStep(collection: collection, onPick: picked)
        case let .savour(step):
            savourView(step)
        case .seal:
            SealStep(collection: collection, savouring: $savouring, onSeal: seal)
        }
    }

    @ViewBuilder
    private func savourView(_ step: SavourStep) -> some View {
        switch step {
        case let .duel(count):
            if let item {
                DuelStep(newcomer: item, ranked: rankedOthers(than: item), count: count) { position in
                    savouring.rankPosition = position
                    stage = .seal
                } onSkip: {
                    // Sealed without a place: it stays unranked and duels next time.
                    savouring.rankPosition = nil
                    stage = .seal
                }
            }
        case let .still(rank):
            StillStep(rank: rank) {
                stage = .seal
            } reRank: {
                if let item {
                    stage = .savour(.duel(count: rankedOthers(than: item).count))
                }
            }
        case .relish:
            RelishStep(rating: savouring.rating) { rating in
                savouring.rating = rating
                stage = .seal
            }
        case .when:
            WhenStep(times: QuickLogFlow.timesLabel(previousEntries: item?.entries?.count ?? 0)) { when in
                savouring.date = when.date(from: .now)
                stage = .seal
            }
        case .stamp:
            StampItStep {
                stage = .seal
            }
        }
    }

    private func rankedOthers(than item: Item) -> [Item] {
        repository.ranking(of: collection).filter { $0.id != item.id }
    }

    private func picked(_ chosen: Item) {
        item = chosen
        let ranking = repository.ranking(of: collection)
        let rank = ranking.firstIndex { $0.id == chosen.id }
        let step = QuickLogFlow.step(for: collection.ratingMode, rank: rank, othersRanked: rankedOthers(than: chosen).count)
        // A first ranked item has nothing to duel: it's No. 1.
        if step == .duel(count: 0) {
            savouring.rankPosition = 0
            stage = .seal
        } else {
            stage = .savour(step)
        }
    }

    private func seal() {
        guard let item else { return }
        do {
            let entry = try repository.savour(item, savouring)
            onSealed(QuickLogFlow.toast(seconds: Date.now.timeIntervalSince(startedAt), collection: collection.name), entry.id)
        } catch {
            assertionFailure("Sealing failed: \(error)")
        }
    }
}
