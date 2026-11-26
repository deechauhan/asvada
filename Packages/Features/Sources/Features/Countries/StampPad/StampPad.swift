import DesignSystem
import Geo
import SwiftUI

/// The stamp pad (docs/design/INTERACTION.md §6, flat map): stamp countries by aiming a rubber
/// stamp at the ink map, by tapping through a strip of unstamped stamps, or by typing a name
/// and pressing Return. Each stamp thunks, blooms ink from where it hit, lands in the passport
/// strip and rolls the counter. Long-press a stamp in the passport to wash it off, with Undo.
struct StampPad: View {
    @Binding var stamped: Set<String>
    /// Whether the pad shows its own rolling "23 countries · 12% of the world". The Countries
    /// drawer turns it off: its passport panel already leads with the same count and a ring.
    var showsCounter = true
    @State private var continent: Continent?
    @State private var query = ""
    /// The country the reticle is on (from search, a tap on the map, or the stamp's foot).
    @State private var aim: StampAim?
    /// Where the finger is while it carries the rubber stamp, in the map's points.
    @State private var finger: CGPoint?
    @State private var bloom: InkBloom?
    /// Newest stamps first.
    @State private var order: [String] = []
    /// The stamp just made: it thunks into the passport strip.
    @State private var latest: String?
    @State private var stampsMade = 0
    @State private var washedOff: String?
    @State private var showsList = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let world = InkWorld.shared
    private let catalog = CountryCatalog.shared
    static let mapSpace = "stampPadMap"

    private var strip: [Country] {
        StampPadLogic.strip(continent: continent, query: query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            map
                .zIndex(1)
            counter
            search
            StampContinentChips(selection: $continent)
            StampStrip(
                title: StampPadLogic.stripTitle(continent: continent, strip: strip, stamped: stamped),
                countries: strip,
                stamped: stamped,
                onStamp: { stamp($0, at: nil) },
                onWashOff: washOff,
            )
            if !order.isEmpty {
                PassportStrip(codes: order, latest: latest, onWashOff: washOff)
            }
        }
        .overlay(alignment: .bottom) {
            if let washedOff, let country = catalog.country(code: washedOff) {
                WashOffBar(country: country.name, onUndo: undoWashOff)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .haptic(.stamp, trigger: stampsMade)
        .onAppear { order = StampPadLogic.passportOrder(order, stamped: stamped) }
        .onChange(of: stamped) { order = StampPadLogic.passportOrder(order, stamped: stamped) }
        .task(id: washedOff) {
            guard washedOff != nil else { return }
            try? await Task.sleep(for: .seconds(5))
            withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) { washedOff = nil }
        }
        .sheet(isPresented: $showsList) {
            NavigationStack {
                CountryPicker(selection: $stamped)
                    .navigationTitle("A to Z")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showsList = false }
                        }
                    }
            }
        }
    }

    // MARK: - The map

    private var map: some View {
        InkWorldMap(visited: stamped, unInked: bloom?.code) { code in
            stamp(code, at: nil)
        }
        .overlay {
            GeometryReader { proxy in
                ZStack {
                    if let bloom {
                        InkBloomLayer(bloom: bloom) {
                            if self.bloom?.id == bloom.id {
                                self.bloom = nil
                            }
                        }
                        .id(bloom.id)
                    }
                    if let aim, finger == nil {
                        StampReticle(label: aimLabel(aim))
                            .position(x: aim.point.x * proxy.size.width, y: aim.point.y * proxy.size.height)
                    }
                    if let finger {
                        loupe(at: StampPadLogic.foot(forFinger: finger), in: proxy.size)
                    }
                    RubberStampHandle(isLifted: finger != nil, aimed: aim.flatMap { catalog.country(code: $0.code)?.name }) {
                        if let aim {
                            stamp(aim.code, at: aim.point)
                        }
                    }
                    .position(finger ?? CGPoint(x: proxy.size.width - 30, y: proxy.size.height - 28))
                    // Above any scroll view the pad sits in, so carrying the stamp never scrolls.
                    .highPriorityGesture(carry(in: proxy.size))
                }
            }
            .coordinateSpace(.named(Self.mapSpace))
        }
    }

    private func loupe(at foot: CGPoint, in size: CGSize) -> some View {
        let centre = StampPadLogic.unit(foot, in: size)
        return ZStack {
            StampLoupe(centre: centre, mapSize: size, stamped: stamped, label: centre.flatMap(name(atUnit:)))
                .position(StampPadLogic.loupePosition(foot: foot, mapSize: size))
            // Where the stamp will land: the dashed ring under the foot.
            Circle()
                .strokeBorder(Palette.brand.color, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(width: 26, height: 26)
                .position(foot)
                .allowsHitTesting(false)
        }
    }

    /// Carrying the rubber stamp: the foot aims, the loupe shows what's under it, lifting stamps.
    /// A tap without carrying stamps wherever the reticle already is.
    private func carry(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.mapSpace))
            .onChanged { value in
                guard hypot(value.translation.width, value.translation.height) > 6 || finger != nil else { return }
                finger = value.location
                let foot = StampPadLogic.foot(forFinger: value.location)
                if let unit = StampPadLogic.unit(foot, in: size), let code = world.code(atUnit: unit) {
                    aim = StampAim(code: code, point: unit)
                }
            }
            .onEnded { value in
                defer { finger = nil }
                guard finger != nil else {
                    if let aim {
                        stamp(aim.code, at: aim.point)
                    }
                    return
                }
                let foot = StampPadLogic.foot(forFinger: value.location)
                if let unit = StampPadLogic.unit(foot, in: size), let code = world.code(atUnit: unit) {
                    aim = StampAim(code: code, point: unit)
                    stamp(code, at: unit)
                }
            }
    }

    // MARK: - Counter and search

    private var counter: some View {
        HStack(alignment: .firstTextBaseline) {
            if showsCounter {
                Text(PassportSpreadCard.title(count: stamped.count, worldTotal: DrawerSummary.worldCountries))
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.brand.color)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("stampCounter")
            }
            Spacer(minLength: Spacing.small)
            Button("A to Z") { showsList = true }
                .typeToken(.callout)
                .accessibilityHint("Every country in a list")
                .accessibilityIdentifier("stampList")
        }
    }

    private var search: some View {
        TextField("Find a country, Return stamps it", text: $query)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .onChange(of: query) { fly(to: query) }
            .onSubmit(stampSearch)
            .accessibilityIdentifier("stampSearch")
    }

    // MARK: - Actions

    private func name(atUnit point: CGPoint) -> String? {
        world.code(atUnit: point).flatMap { catalog.country(code: $0)?.name }
    }

    private func aimLabel(_ aim: StampAim) -> String {
        catalog.country(code: aim.code).map { StampPadLogic.aimLabel($0, stamped: stamped) } ?? aim.code
    }

    /// Flies the reticle to the best match for `query`.
    private func fly(to query: String) {
        guard let country = StampPadLogic.flyTarget(for: query), let shape = world.shape(code: country.code) else { return }
        withAnimation(Motion.animation(.easeInOut(duration: 0.75), reduceMotion: reduceMotion)) {
            aim = StampAim(code: country.code, point: shape.anchor)
        }
    }

    /// Return in the search field: stamp the country the reticle flew to, then clear for the next.
    private func stampSearch() {
        guard let country = StampPadLogic.flyTarget(for: query) ?? catalog.search(query).first else { return }
        stamp(country.code, at: nil)
        query = ""
    }

    /// Stamps `code`, blooming ink from `origin` (unit space; the country's middle if nil).
    private func stamp(_ code: String, at origin: CGPoint?) {
        let point = origin ?? world.shape(code: code)?.anchor
        if let point {
            aim = StampAim(code: code, point: point)
        }
        guard !stamped.contains(code) else { return }
        if let point {
            bloom = InkBloom(code: code, origin: point)
        }
        latest = code
        withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) {
            stamped.insert(code)
            stampsMade += 1
        }
    }

    private func washOff(_ code: String) {
        guard stamped.contains(code) else { return }
        withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) {
            stamped.remove(code)
            washedOff = code
        }
    }

    private func undoWashOff() {
        guard let code = washedOff else { return }
        withAnimation(Motion.animation(.snappy, reduceMotion: reduceMotion)) {
            stamped.insert(code)
            washedOff = nil
        }
    }
}

#Preview {
    @Previewable @State var stamped: Set = ["JP", "PT", "PE"]
    ScrollView {
        StampPad(stamped: $stamped)
            .padding()
    }
}
