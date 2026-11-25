import DesignSystem
import Geo
import Model
import Ranking
import Sources
import Storage
import SwiftData
import SwiftUI

/// "What was it?": the print head prints its best guess onto the blank (tear it off for the next,
/// or "That's it"); typing prints the top result instead. Things already in the drawer match as
/// you go, and anything new is added by hand. Countries match the bundled catalogue.
struct PickStep: View {
    let collection: ExperienceCollection
    let onPick: (Item) -> Void

    @Environment(\.modelContext) private var context
    @State private var query = ""
    @FocusState private var focused: Bool
    @State private var head = PrintHead()
    /// The top result for what's typed, printed instead of the guesses while typing.
    @State private var typed: Guess?
    @State private var whereYouAre = WhereYouAre()
    @State private var tears = 0
    private let search = MapKitPlaceSearch()
    private let tmdb = TMDBClient(configuration: TMDBConfiguration.fromBundle())

    /// What the blank shows: the typed top result while typing, else the print head's guess.
    private var printed: Guess? {
        trimmed.isEmpty ? head.current : typed
    }

    private var sourceLine: String? {
        trimmed.isEmpty ? head.sourceLine : typed.map { _ in GuessSource.typed.title }
    }

    /// Whether this drawer can guess from where you are.
    private var guessesFromLocation: Bool {
        collection.itemSource == .countryCatalog || Guesses.placeKind(of: collection) != nil
    }

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isCountries: Bool {
        collection.itemSource == .countryCatalog
    }

    private var matches: [Item] {
        Array(QuickLogFlow.matches(collection.items ?? [], query: query).prefix(6))
    }

    private var countries: [Country] {
        guard isCountries, !trimmed.isEmpty else { return [] }
        let known = Set((collection.items ?? []).compactMap(\.countryCode))
        return Array(CountryCatalog.shared.search(trimmed).filter { !known.contains($0.code) }.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            PrintedBlank(
                collection: collection,
                guess: printed,
                sourceLine: sourceLine,
                canRestore: trimmed.isEmpty && head.canRestore,
                onTear: tear,
                onRestore: restore,
            )
            .frame(maxWidth: .infinity)
            .haptic(.tear, trigger: tears)
            if let printed {
                HStack(spacing: Spacing.medium) {
                    Button("That's it") { accept(printed) }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.brand.color)
                        .accessibilityIdentifier("printAccept")
                    if trimmed.isEmpty {
                        Button("Next guess", action: tear)
                            .buttonStyle(.bordered)
                            .tint(Palette.brand.color)
                            .accessibilityIdentifier("printNext")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            if guessesFromLocation, whereYouAre.canAsk {
                Button("Guess from where you are", systemImage: "location") { whereYouAre.ask() }
                    .typeToken(.callout)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("printUseLocation")
            }
            TextField("What was it?", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.system(.title3, design: .serif))
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.next)
                .onSubmit(submit)
                .accessibilityIdentifier("quickLogName")
            ForEach(matches) { item in
                choice(item.name, systemImage: "arrow.uturn.right", id: "pick-\(item.name)") { onPick(item) }
            }
            ForEach(countries) { country in
                choice("\(country.flag) \(country.name)", systemImage: "seal", id: "pick-\(country.name)") { pick(country) }
            }
            if !trimmed.isEmpty, !isCountries, !QuickLogFlow.hasExactMatch(collection.items ?? [], query: trimmed) {
                choice("Add “\(trimmed)”", systemImage: "square.and.pencil", id: "quickLogAddNew", action: addNew)
            }
        }
        .task { await gatherGuesses() }
        .onChange(of: whereYouAre.isAllowed) { _, allowed in
            if allowed {
                Task { await gatherLocalGuesses() }
            }
        }
        .task(id: trimmed) {
            guard !trimmed.isEmpty else {
                typed = nil
                return
            }
            // Wait for a pause in typing before searching.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let point = await whereYouAre.current()
            typed = await Guesses.top(for: trimmed, in: collection, near: point, search: search, tmdb: tmdb)
        }
    }

    /// Prints what's known at once (the drawer's recent things), opens the keyboard only if
    /// there's nothing to guess, then adds guesses from where you are and the network.
    private func gatherGuesses() async {
        head = PrintHead(guesses: Guesses.again(in: collection))
        focused = head.current == nil
        await gatherLocalGuesses()
        await head.append(Guesses.nowShowing(in: collection, tmdb: tmdb))
    }

    private func gatherLocalGuesses() async {
        guard guessesFromLocation, let point = await whereYouAre.current() else { return }
        head.append(Guesses.youreIn(at: point, in: collection))
        await head.append(Guesses.nearYou(at: point, in: collection, search: search))
    }

    private func tear() {
        if head.tear() {
            tears += 1
        }
    }

    private func restore() {
        head.restore()
    }

    private func accept(_ guess: Guess) {
        onPick(Guesses.accept(guess, in: collection, repository: Repository(context: context)))
    }

    private func choice(_ title: String, systemImage: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .typeToken(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.medium)
                .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    /// Return picks the first match, or adds what was typed.
    private func submit() {
        if let first = matches.first, !trimmed.isEmpty {
            onPick(first)
        } else if let country = countries.first {
            pick(country)
        } else if !trimmed.isEmpty, !isCountries {
            addNew()
        }
    }

    private func addNew() {
        guard let item = try? Repository(context: context).addManualItem(ManualItemDraft(name: trimmed), in: collection)
        else { return }
        onPick(item)
    }

    private func pick(_ country: Country) {
        let item = Repository(context: context).upsertItem(
            named: country.name,
            externalRef: "iso:\(country.code)",
            in: collection,
        )
        item.countryCode = country.code
        onPick(item)
    }
}

/// Ranked and new: "Which did you savour more?", halving the ranking each time, at most
/// ⌈log₂(n+1)⌉ picks, with saffron macron steps and *Too close to call*.
struct DuelStep: View {
    let newcomer: Item
    let ranked: [Item]
    let onPlaced: (Int) -> Void
    @State private var insertion: BinaryInsertion

    init(newcomer: Item, ranked: [Item], count _: Int, onPlaced: @escaping (Int) -> Void) {
        self.newcomer = newcomer
        self.ranked = ranked
        self.onPlaced = onPlaced
        _insertion = State(initialValue: BinaryInsertion(count: ranked.count))
    }

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text(QuickLogFlow.duelQuestion)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
                .accessibilityAddTraits(.isHeader)
            if let index = insertion.comparisonIndex, ranked.indices.contains(index) {
                HStack(spacing: Spacing.medium) {
                    card(newcomer.name, id: "duelNew") { record(.better) }
                    card(ranked[index].name, id: "duelOther") { record(.worse) }
                }
                MacronSteps(
                    done: insertion.comparisonsMade,
                    total: insertion.comparisonsMade + insertion.remainingComparisonsAtMost,
                )
                HStack {
                    if insertion.canUndo {
                        Button("Undo") { insertion.undo() }
                            .accessibilityIdentifier("duelUndo")
                    }
                    Spacer()
                    Button("Too close to call") { record(.worse) }
                        .accessibilityIdentifier("duelTie")
                }
                .typeToken(.callout)
            }
        }
    }

    private func card(_ name: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Palette.textPrimary.color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 96)
                .padding(Spacing.small)
                .background(Palette.keepsakePaper.color, in: RoundedRectangle(cornerRadius: Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: Radius.medium).strokeBorder(Palette.separator.color))
        }
        .buttonStyle(.plain)
        .haptic(.pick, trigger: insertion.comparisonsMade)
        .accessibilityLabel("\(name) was better")
        .accessibilityIdentifier(id)
    }

    /// Ties go just below the item shown.
    private func record(_ verdict: Verdict) {
        insertion.record(verdict)
        if let position = insertion.position {
            onPlaced(position)
        }
    }
}

/// The duel's progress: one saffron macron bar per question.
private struct MacronSteps: View {
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0 ..< max(total, 1), id: \.self) { step in
                Capsule()
                    .fill(step < done ? Palette.saffron.color : Palette.separator.color)
                    .frame(width: 22, height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Question \(min(done + 1, max(total, 1))) of at most \(max(total, 1))")
    }
}

/// Ranked repeat: "Still No. 2?" — yes skips ahead; re-rank duels again.
struct StillStep: View {
    let rank: Int
    let yes: () -> Void
    let reRank: () -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text("Still No. \(rank)?")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
            Button("Still No. \(rank)", action: yes)
                .buttonStyle(.borderedProminent)
                .tint(Palette.brand.color)
                .accessibilityIdentifier("stillYes")
            Button("Rank it again", action: reRank)
                .accessibilityIdentifier("stillRerank")
        }
    }
}

/// Stars: five ā marks; the relish word prints under them.
struct RelishStep: View {
    let rating: Double?
    let onRate: (Double) -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text("How did it land?")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
            HStack(spacing: Spacing.small) {
                ForEach(1 ... Relish.words.count, id: \.self) { step in
                    Button {
                        onRate(Double(step))
                    } label: {
                        Text("ā")
                            .font(.system(size: 28, weight: .heavy, design: .serif))
                            .foregroundStyle(Double(step) <= (rating ?? 0) ? Palette.brand.color : Palette.textSecondary.color)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Relish.words[step - 1])
                    .accessibilityIdentifier("relish-\(step)")
                }
            }
            Text(Relish.word(for: rating) ?? "Tap an ā")
                .font(.system(.body, design: .serif).italic())
                .foregroundStyle(Palette.textSecondary.color)
        }
    }
}

/// Log: when was it?
struct WhenStep: View {
    let times: String?
    let onPick: (LogWhen) -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text("When?")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
            HStack(spacing: Spacing.small) {
                ForEach(LogWhen.allCases) { when in
                    Button(when.title) { onPick(when) }
                        .buttonStyle(.bordered)
                        .tint(Palette.brand.color)
                        .accessibilityIdentifier("when-\(when.title)")
                }
            }
            if let times {
                Text(times)
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
    }
}

/// Checklist: stamp it into the passport.
struct StampItStep: View {
    let onStamp: () -> Void

    var body: some View {
        Button(action: onStamp) {
            Label("Stamp", systemImage: "seal.fill")
                .typeToken(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.small)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.brand.color)
        .accessibilityIdentifier("stampItButton")
    }
}

/// The seal: an optional note to your future self, then hold the ā.
struct SealStep: View {
    let collection: ExperienceCollection
    @Binding var savouring: Savouring
    let onSeal: () -> Void
    @Environment(\.modelContext) private var context
    @State private var showsDetails = false

    private var summary: String? {
        if let position = savouring.rankPosition {
            return "No. \(position + 1) in \(collection.name)"
        }
        return Relish.word(for: savouring.rating)
    }

    var body: some View {
        VStack(spacing: Spacing.large) {
            if let summary {
                Text(summary)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Palette.brand.color)
                    .accessibilityIdentifier("quickLogSummary")
            }
            TextField("A note to your future self", text: $savouring.note, axis: .vertical)
                .font(.system(.body, design: .serif).italic())
                .lineLimit(1 ... 4)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("quickLogNote")
            Button {
                showsDetails.toggle()
            } label: {
                Label("When, who with, tags, photos", systemImage: showsDetails ? "chevron.down" : "chevron.right")
                    .typeToken(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.brand.color)
            .accessibilityValue(showsDetails ? "Shown" : "Hidden")
            .accessibilityIdentifier("quickLogDetails")
            if showsDetails {
                EntryDetailsFields(
                    date: $savouring.date,
                    people: $savouring.people,
                    tags: $savouring.tags,
                    knownPeople: Repository(context: context).peopleNames(),
                    knownTags: Repository(context: context).tagNames(),
                )
                EntryPhotosField(
                    thumbnails: savouring.photos.enumerated().map { index, photo in
                        PhotoThumbnail(id: "picked-\(index)", data: photo.thumbnailData)
                    },
                    onAdd: { savouring.photos += $0 },
                    onRemove: { thumbnail in
                        if let index = Int(thumbnail.id.replacingOccurrences(of: "picked-", with: "")),
                           savouring.photos.indices.contains(index)
                        {
                            savouring.photos.remove(at: index)
                        }
                    },
                )
            }
            SealButton(action: onSeal)
            Text("Hold the ā to seal it")
                .font(.caption)
                .foregroundStyle(Palette.textSecondary.color)
        }
    }
}
