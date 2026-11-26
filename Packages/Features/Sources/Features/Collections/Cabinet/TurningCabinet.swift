import DesignSystem
import Model
import SwiftUI

/// The turning cabinet (docs/design/INTERACTION.md §3, ADR-0004): every collection is a drawer
/// on a revolving column. One drawer sits big and centred; swipe and the column rolls to the
/// next, clicking once per drawer, then the front drawer eases ajar and its best keepsakes rise.
/// Pull the front drawer toward you (or tap it) to open it. The blank drawer at the end of the
/// ring starts a new collection.
///
/// VoiceOver never meets the 3D drum: it gets a plain ordered list of drawers with Open, Move
/// earlier, Move later, Put away and Share actions. Under Reduce Motion the drum is drawn flat
/// and drawers crossfade; haptics stay.
struct TurningCabinet: View {
    /// The drawers in cabinet order (hidden collections excluded).
    let collections: [ExperienceCollection]
    /// The drawer last brought to the front, remembered across launches.
    @Binding var frontID: String
    var actions: CabinetActions
    /// Where opened drawers zoom out of.
    let namespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drum = CabinetDrum(count: 0)
    @State private var dragStart: Double?
    @State private var dragAxis: Axis?
    /// When the finger last moved, and where to: a release after a rest flings nowhere.
    @State private var lastMove: (time: Date, translation: CGSize)?
    @State private var pull = 0.0
    @State private var ajar: Int?
    @State private var detents = 0
    @State private var clunks = 0
    /// How wide the cabinet is, for sizing the drawer in focus.
    @State private var width = 0.0
    @AppStorage("cabinet.hintedPull") private var hintedPull = false

    /// How far the front drawer must be pulled (points) before it opens.
    static let pullThreshold = 90.0
    /// A pull released faster than this (points per second) opens the drawer however far it went.
    static let pullFlick = 800.0

    /// A face on the ring: a collection's drawer, or the blank drawer at the end.
    enum Face: Identifiable, Equatable {
        case drawer(ExperienceCollection)
        case blank

        var id: String {
            switch self {
            case let .drawer(collection): collection.id.uuidString
            case .blank: "blank"
            }
        }

        static func == (lhs: Face, rhs: Face) -> Bool {
            lhs.id == rhs.id
        }
    }

    private var faces: [Face] {
        collections.map(Face.drawer) + [.blank]
    }

    var body: some View {
        VStack(spacing: Spacing.large) {
            drumView
            KnobRail(names: faces.map(name), front: drum.frontIndex) { index in
                turn(to: index)
            }
        }
        .onAppear(perform: syncWithCollections)
        .onChange(of: faces.map(\.id)) { _, _ in syncWithCollections() }
    }

    // MARK: - The drum

    /// How much bigger the drawer in focus is drawn (#190). Under Reduce Motion the flat row
    /// keeps every drawer the same size.
    private var frontScale: Double {
        reduceMotion ? 1 : DrawerGeometry.frontScale(forWidth: width, drawerWidth: DrumDrawer.size.width)
    }

    private var drumView: some View {
        ZStack {
            ForEach(Array(faces.enumerated()), id: \.element.id) { index, face in
                faceView(face, index: index)
                    .modifier(DrumFace(
                        position: drum.position,
                        index: index,
                        count: faces.count,
                        reduceMotion: reduceMotion,
                        frontScale: frontScale,
                    ))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: DrumDrawer.size.height * CGFloat(frontScale) + 40)
        .onGeometryChange(for: Double.self, of: { Double($0.size.width) }, action: { width = $0 })
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .detentHaptic(trigger: detents)
        .haptic(.clunk, trigger: clunks)
        .accessibilityRepresentation {
            CabinetAccessibleList(collections: collections, actions: actions)
        }
        .accessibilityIdentifier("turningCabinet")
    }

    @ViewBuilder
    private func faceView(_ face: Face, index: Int) -> some View {
        let isFront = index == drum.frontIndex
        switch face {
        case let .drawer(collection):
            DrumDrawer(
                collection: collection,
                isAjar: ajar == index,
                pull: isFront ? pull : 0,
                onAnniversary: { actions.onThisDay(collection) },
            )
            .zoomSource(id: collection.id, in: namespace)
            .offset(y: isFront ? pull * 0.5 : 0)
            .scaleEffect(isFront ? 1 + pull / 1000 : 1)
            .onTapGesture { tap(index) }
            .contextMenu {
                Button("Open", systemImage: "tray.and.arrow.down") { actions.open(collection) }
                Button("Customise", systemImage: "slider.horizontal.3") { actions.customise(collection) }
                if ShareContent(collection: collection) != nil {
                    Button("Share", systemImage: "square.and.arrow.up") { actions.share(collection) }
                }
                Button("Put away", systemImage: "archivebox") { actions.hide(collection) }
            }
        case .blank:
            BlankDrawer()
                .onTapGesture { tap(index) }
        }
    }

    private func name(of face: Face) -> String {
        switch face {
        case let .drawer(collection): collection.name
        case .blank: "New collection"
        }
    }

    // MARK: - Gestures

    /// Horizontal drags roll the drum; vertical drags pull the front drawer. The axis locks after
    /// the first 10 points of travel.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if lastMove?.translation != value.translation {
                    lastMove = (value.time, value.translation)
                }
                if dragAxis == nil {
                    let horizontal = abs(value.translation.width) >= abs(value.translation.height)
                    dragAxis = horizontal ? .horizontal : .vertical
                    dragStart = drum.position
                    ajar = nil
                }
                switch dragAxis {
                case .horizontal: roll(by: value.translation.width)
                case .vertical: pull = Self.pullOffset(for: value.translation.height)
                case nil: break
                }
            }
            .onEnded { value in
                let rest = lastMove.map { value.time.timeIntervalSince($0.time) } ?? 0
                switch dragAxis {
                case .horizontal:
                    let velocity = CabinetDrum.releaseVelocity(value.velocity.width, restedFor: rest)
                    settle(to: drum.restingPosition(afterReleaseAt: velocity))
                case .vertical:
                    endPull(velocity: CabinetDrum.releaseVelocity(value.velocity.height, restedFor: rest))
                case nil: break
                }
                dragAxis = nil
                dragStart = nil
                lastMove = nil
            }
    }

    /// How far the drawer follows a vertical drag: toward you it rubber-bands loosely, away from
    /// you it barely moves (a drawer doesn't go further into the cabinet).
    static func pullOffset(for translation: Double) -> Double {
        translation >= 0
            ? Motion.rubberBand(translation, dimension: 320, coefficient: 0.75)
            : -Motion.rubberBand(-translation, dimension: 40)
    }

    private func roll(by translation: Double) {
        let before = drum.frontIndex
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            drum.position = drum.position(dragging: translation, from: dragStart ?? drum.position)
        }
        if drum.frontIndex != before {
            detents += 1
        }
    }

    /// Springs the drum to `target`, clicking once per drawer it passes, then eases the new front
    /// drawer ajar.
    private func settle(to target: Double) {
        let passed = Int(abs(target.rounded() - drum.position.rounded()))
        for step in 0 ..< passed {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60 * (step + 1)))
                detents += 1
            }
        }
        withAnimation(Motion.animation(Motion.roll, reduceMotion: reduceMotion)) {
            drum.position = target
        } completion: {
            settled()
        }
    }

    private func settled() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            drum = drum.normalised()
        }
        let front = drum.frontIndex
        if faces.indices.contains(front) {
            frontID = faces[front].id
        }
        withAnimation(Motion.animation(Motion.settle, reduceMotion: reduceMotion)) {
            ajar = front
        }
        hintPullOnce()
    }

    private func turn(to index: Int) {
        guard faces.indices.contains(index), index != drum.frontIndex || ajar == nil else { return }
        ajar = nil
        settle(to: drum.position(turningTo: index))
    }

    private func tap(_ index: Int) {
        if index == drum.frontIndex {
            open(index)
        } else {
            turn(to: index)
        }
    }

    private func endPull(velocity: Double) {
        let opens = pull >= Self.pullThreshold || (pull > 20 && velocity >= Self.pullFlick)
        withAnimation(Motion.animation(Motion.pull, reduceMotion: reduceMotion)) {
            pull = 0
        }
        if opens {
            open(drum.frontIndex)
        }
    }

    private func open(_ index: Int) {
        guard faces.indices.contains(index) else { return }
        clunks += 1
        switch faces[index] {
        case let .drawer(collection): actions.open(collection)
        case .blank: actions.create()
        }
    }

    /// The first time a drawer settles ajar, it bobs toward you once to show it can be pulled.
    private func hintPullOnce() {
        // A tip in spirit: UI tests turn tips off, and the bob would move drawers under them.
        guard !hintedPull, !reduceMotion, !Self.arguments.contains("-disableTips") else { return }
        hintedPull = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard dragAxis == nil else { return }
            withAnimation(Motion.pull) { pull = 26 }
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(Motion.pull) { pull = 0 }
        }
    }

    // MARK: - Keeping up with the collections

    /// Rebuilds the ring when drawers are added, removed or reordered, keeping the remembered
    /// drawer at the front.
    private func syncWithCollections() {
        let index = faces.firstIndex { $0.id == frontID } ?? 0
        var transaction = Transaction()
        transaction.disablesAnimations = true
        // `-cabinetMidRoll` stops the drum between two drawers, for screenshots of a roll.
        let midRoll = Self.arguments.contains("-cabinetMidRoll")
        withTransaction(transaction) {
            drum = CabinetDrum(count: faces.count, position: Double(index) + (midRoll ? 0.45 : 0))
            ajar = midRoll ? nil : index
        }
    }

    private static let arguments = ProcessInfo.processInfo.arguments
}

/// What the cabinet asks its screen to do.
struct CabinetActions {
    var open: (ExperienceCollection) -> Void
    var create: () -> Void
    var customise: (ExperienceCollection) -> Void
    var share: (ExperienceCollection) -> Void
    var hide: (ExperienceCollection) -> Void
    var move: (ExperienceCollection, Int) -> Void
    /// Pulls out what a drawer holds from this day in earlier years (#69).
    var onThisDay: (ExperienceCollection) -> Void = { _ in }
}

/// Places one face on the drum. Animatable in the drum's position, so a spring carries every
/// drawer round the arc rather than sliding it in a straight line.
private struct DrumFace: ViewModifier, Animatable {
    var position: Double
    let index: Int
    let count: Int
    let reduceMotion: Bool
    /// The extra size of the drawer in focus.
    let frontScale: Double

    nonisolated var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    func body(content: Content) -> some View {
        let offset = CabinetDrum(count: count, position: position).offset(of: index)
        let geometry = DrawerGeometry(
            offset: offset,
            count: count,
            drawerWidth: DrumDrawer.size.width,
            reduceMotion: reduceMotion,
        )
        content
            .brightness(-geometry.shade * 0.45)
            .rotation3DEffect(.degrees(geometry.rotation), axis: (x: 0, y: 1, z: 0), perspective: DrawerGeometry.perspective)
            .scaleEffect(geometry.scale * DrawerGeometry.focusScale(offset: offset, frontScale: frontScale))
            .offset(x: geometry.x)
            .opacity(geometry.opacity)
            .zIndex(geometry.zIndex)
            .allowsHitTesting(geometry.isVisible && abs(offset) < 1.5)
    }
}

/// The row of knobs under the drum: one per drawer, the front one lit. Each is a real button
/// ("Turn to Films"), so Switch Control and Voice Control can turn the cabinet too.
private struct KnobRail: View {
    let names: [String]
    let front: Int
    let turn: (Int) -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                Button {
                    turn(index)
                } label: {
                    Capsule()
                        .fill(index == front ? Palette.brand.color : Palette.textSecondary.color.opacity(0.3))
                        .frame(width: index == front ? 18 : 7, height: 7)
                        .frame(minWidth: 20, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Turn to \(name)")
                .accessibilityAddTraits(index == front ? .isSelected : [])
            }
        }
        .animation(.snappy, value: front)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("knobRail")
    }
}

/// What VoiceOver gets instead of the 3D drum: the drawers as a plain ordered list, each with its
/// stat and the drawer actions.
private struct CabinetAccessibleList: View {
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
