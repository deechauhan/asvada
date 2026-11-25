import DesignSystem
import Geo
import Model
import Ranking
import Sources
import Storage
import SwiftData
import SwiftUI

/// "What was it?": the print head prints its best guess onto the blank (tear it off for the next,
/// or "That's it"); typing prints the top result instead. Below, things already in the drawer
/// match as you go, then up to eight numbered results from Apple Maps, TMDB or the catalogue
/// (places as a list or on a map), and anything new is added by hand.
struct PickStep: View {
    let collection: ExperienceCollection
    let onPick: (Item) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.placeSearch) private var search
    @State private var query = ""
    @FocusState private var focused: Bool
    @State private var head = PrintHead()
    /// The top result for what's typed, printed instead of the guesses while typing.
    @State private var typed: Guess?
    @State private var whereYouAre = WhereYouAre()
    @State private var tears = 0
    /// What the last search found (kept while the next one runs, so rows don't blink).
    @State private var results = SearchResults.empty
    @State private var isSearching = false
    /// What `results` were found for.
    @State private var searchedFor = ""
    /// List or map, remembered per collection.
    @AppStorage private var layout: ResultsLayout
    private let tmdb = TMDBClient(configuration: TMDBConfiguration.fromBundle())

    init(collection: ExperienceCollection, onPick: @escaping (Item) -> Void) {
        self.collection = collection
        self.onPick = onPick
        _layout = AppStorage(wrappedValue: .list, ResultsLayout.storageKey(for: collection))
    }

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

    /// The drawer's matches as you type, plus any search result the drawer already holds.
    private var drawerItems: [Item] {
        guard !trimmed.isEmpty else { return [] }
        var items = matches
        for item in results.drawer where searchedFor == trimmed && !items.contains(where: { $0.id == item.id }) {
            items.append(item)
        }
        return items
    }

    /// Places can be shown on a map as well as listed.
    private var showsMapSwitch: Bool {
        collection.itemSource == .mapkit && Guesses.placeKind(of: collection) != nil
    }

    private var canAddNew: Bool {
        !trimmed.isEmpty && !isCountries && !QuickLogFlow.hasExactMatch(collection.items ?? [], query: trimmed)
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
            // The row keeps its place even with nothing printed, so the matches below don't
            // jump when a typed result arrives (a tap mid-jump lands on the wrong row).
            HStack(spacing: Spacing.medium) {
                Button("That's it") {
                    if let printed {
                        accept(printed)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.brand.color)
                .accessibilityIdentifier("printAccept")
                Button("Next guess", action: tear)
                    .buttonStyle(.bordered)
                    .tint(Palette.brand.color)
                    .opacity(trimmed.isEmpty ? 1 : 0)
                    .disabled(!trimmed.isEmpty)
                    .accessibilityHidden(!trimmed.isEmpty)
                    .accessibilityIdentifier("printNext")
            }
            .frame(maxWidth: .infinity)
            .opacity(printed == nil ? 0 : 1)
            .disabled(printed == nil)
            .accessibilityHidden(printed == nil)
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
            if !drawerItems.isEmpty {
                groupTitle("In your drawer")
            }
            ForEach(drawerItems) { item in
                choice(item.name, systemImage: "arrow.uturn.right", id: "pick-\(item.name)") { onPick(item) }
            }
            // Above the search results, so results arriving later never move it under a finger.
            if canAddNew {
                choice("Add “\(trimmed)”", systemImage: "square.and.pencil", id: "quickLogAddNew", action: addNew)
            }
            if !trimmed.isEmpty, let source = SearchResults.sourceTitle(for: collection.itemSource) {
                foundSection(source)
            }
        }
        .onChange(of: layout) { _, newLayout in
            if newLayout == .map {
                focused = false
            }
        }
        .task { await gatherGuesses() }
        .onChange(of: whereYouAre.isAllowed) { _, allowed in
            if allowed {
                Task { await gatherLocalGuesses() }
            }
        }
        .task(id: trimmed) { await runSearch() }
    }

    /// Searches for what's typed after a pause in typing (at once for the bundled catalogues).
    private func runSearch() async {
        guard !trimmed.isEmpty else {
            typed = nil
            results = .empty
            searchedFor = ""
            isSearching = false
            return
        }
        isSearching = true
        let isCatalogue = collection.itemSource == .countryCatalog || collection.itemSource == .airlineCatalog
        if !isCatalogue {
            try? await Task.sleep(for: .milliseconds(300))
        }
        guard !Task.isCancelled else { return }
        // The drawer's own match prints at once; the source's results follow.
        if let item = matches.first {
            typed = Guess(id: "item:\(item.id)", title: item.name, source: .typed, subject: .item(item))
        }
        let point = await whereYouAre.current()
        let found = await Guesses.results(for: trimmed, in: collection, near: point, search: search, tmdb: tmdb)
        guard !Task.isCancelled else { return }
        results = found
        searchedFor = trimmed
        typed = found.top
        isSearching = false
    }

    private func groupTitle(_ title: String) -> some View {
        Text(title)
            .typeToken(.ticketLabel)
            .foregroundStyle(Palette.textSecondary.color)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func foundSection(_ source: String) -> some View {
        HStack {
            groupTitle(source)
            Spacer(minLength: 0)
            if showsMapSwitch {
                Picker("Show results as", selection: $layout) {
                    ForEach(ResultsLayout.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .accessibilityIdentifier("resultsLayout")
            }
        }
        if showsMapSwitch, layout == .map {
            ResultsMap(found: results.found, held: drawerItems, onPick: accept, onPickHeld: onPick)
        } else {
            ForEach(results.found) { found in
                FoundRow(found: found) { accept(found.guess) }
            }
        }
        if results.found.isEmpty {
            Text(isSearching ? "Looking…" : "Nothing found for “\(trimmed)”.")
                .typeToken(.callout)
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityIdentifier("resultsStatus")
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

    /// Return picks the first match, else the first result, else adds what was typed.
    private func submit() {
        if let first = drawerItems.first {
            onPick(first)
        } else if let found = results.found.first {
            accept(found.guess)
        } else if canAddNew {
            addNew()
        }
    }

    private func addNew() {
        guard let item = try? Repository(context: context).addManualItem(ManualItemDraft(name: trimmed), in: collection)
        else { return }
        onPick(item)
    }
}
