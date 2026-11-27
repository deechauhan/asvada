import DesignSystem
import Geo
import SwiftUI

/// The ink globe (docs/design/INTERACTION.md §6, spin & stamp). Spin it with a finger. It coasts,
/// slows, and the magnet pulls the nearest country into the ring. Stamp it with the Stamp button
/// or a double tap; tap a country to fly to it; pinch, or tap Unroll, to unroll it into the flat
/// ink map. VoiceOver: one summarised element with a Stamp action. The search, the continent
/// strips and the A-to-Z list beside it are the accessible path.
struct InkGlobe: View {
    let stamped: Set<String>
    @Binding var movement: GlobeMovement
    /// The country the globe last flew to (search, a chip, a tap or the magnet). The reticle aims
    /// at it even when its middle falls just off its outline. Dragging clears it.
    @Binding var focus: String?
    /// The country blooming in, and how far the bloom has got.
    let bloom: String?
    let bloomProgress: Double
    /// 0 is the globe, 1 the flat map; the pinch drives it, the Unroll button finishes it.
    @Binding var unroll: Double
    let onStamp: (String) -> Void
    /// Called once the globe has unrolled all the way, to swap in the flat map.
    let onUnrolled: () -> Void

    @State private var lastDrag: CGPoint?
    @State private var isDragging = false
    @State private var isPinching = false
    @State private var snaps = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let world = InkGlobeWorld.shared
    private let catalog = CountryCatalog.shared

    var body: some View {
        GeometryReader { proxy in
            let layout = GlobeLayout(size: proxy.size)
            TimelineView(.animation(paused: !movement.isMoving)) { timeline in
                let camera = movement.camera(at: timeline.date)
                let moving = isDragging || movement.isMoving
                ZStack {
                    GlobeCanvas(
                        camera: camera,
                        moving: moving,
                        visited: stamped,
                        bloom: bloom,
                        unroll: unroll,
                        bloomProgress: bloomProgress,
                        reduceMotion: reduceMotion,
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(InkWorldMap.summary(visited: stamped))
                    .accessibilityValue(aimName(camera, layout).map { "Aimed at \($0)" } ?? "Not aimed")
                    .accessibilityHint("Spin to aim the ring. Search or the strips below pick a country too")
                    .accessibilityAction(named: "Stamp") { stampAimed(layout) }
                    .accessibilityIdentifier("inkGlobe")
                    if unroll == 0 {
                        StampReticle(label: reticleLabel(camera, layout), isLocked: !moving && aim(camera, layout) != nil)
                            .position(layout.centre)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(drag(layout))
            .simultaneousGesture(taps(layout))
            .simultaneousGesture(pinch)
            .overlay(alignment: .topTrailing) {
                if unroll == 0 {
                    GlobeButton(title: "Unroll", systemImage: "arrow.down.left.and.arrow.up.right", identifier: "unrollGlobe") {
                        finishUnroll()
                    }
                    .accessibilityHint("Shows the flat map of the whole world")
                }
            }
            .overlay(alignment: .bottom) {
                if unroll == 0 {
                    controls(layout)
                }
            }
            .task(id: movement) { await settle(layout) }
        }
        .haptic(.detent, trigger: snaps)
    }

    // MARK: - Controls

    private func controls(_ layout: GlobeLayout) -> some View {
        let resting = !isDragging && !movement.isMoving
        let camera = movement.destination
        let aimed = aim(camera, layout)
        let chips = resting
            ? GlobeMotion.chips(
                aimed: aimed,
                nearby: GlobeMotion.nearby(world.anchors, projection: layout.projection(camera)),
                isSmall: { world.country(code: $0)?.isSmall ?? false },
            )
            : []
        return HStack(alignment: .bottom, spacing: Spacing.small) {
            if !chips.isEmpty {
                GlobeChips(codes: chips, aimed: aimed) { fly(to: $0) }
            }
            Spacer(minLength: 0)
            GlobeButton(
                title: "Stamp",
                systemImage: "seal.fill",
                identifier: "globeStamp",
                prominent: true,
            ) {
                stampAimed(layout)
            }
            .accessibilityValue(aimed.flatMap { catalog.country(code: $0)?.name } ?? "Not aimed")
            .disabled(aimed == nil)
        }
        .padding(Spacing.small)
    }

    // MARK: - Aiming

    /// The country in the ring: the one the globe flew to, else whatever is under the ring.
    private func aim(_ camera: GlobeCamera, _ layout: GlobeLayout) -> String? {
        if let focus, !isDragging {
            return focus
        }
        return code(at: layout.centre, camera: camera, layout: layout)
    }

    private func aimName(_ camera: GlobeCamera, _ layout: GlobeLayout) -> String? {
        aim(camera, layout).flatMap { catalog.country(code: $0)?.name }
    }

    private func reticleLabel(_ camera: GlobeCamera, _ layout: GlobeLayout) -> String {
        guard let code = aim(camera, layout), let country = catalog.country(code: code) else { return "Open sea" }
        return StampPadLogic.aimLabel(country, stamped: stamped)
    }

    /// The country under a point on screen, by turning the point back into a place.
    private func code(at point: CGPoint, camera: GlobeCamera, layout: GlobeLayout) -> String? {
        guard let place = layout.projection(camera).geoPoint(at: point) else { return nil }
        return InkWorld.shared.code(atUnit: InkWorld.shared.unit(place))
    }

    private func stampAimed(_ layout: GlobeLayout) {
        if let code = aim(movement.camera(at: .now), layout) {
            onStamp(code)
        }
    }

    private func fly(to code: String, duration: Double = GlobeMovement.flightDuration) {
        guard let flight = GlobeMovement.flight(
            from: movement,
            toCountry: code,
            at: .now,
            duration: duration,
            reduceMotion: reduceMotion,
        ) else { return }
        focus = code
        movement = flight
    }

    // MARK: - Motion

    /// When a coast or flight ends: come to rest, and after a coast let the magnet pull the
    /// nearest country into the ring.
    private func settle(_ layout: GlobeLayout) async {
        guard let end = movement.end else { return }
        let wait = end.timeIntervalSinceNow
        if wait > 0 {
            try? await Task.sleep(for: .seconds(wait))
        }
        guard !Task.isCancelled else { return }
        let coasted = movement.isCoasting
        movement = .resting(movement.destination)
        if coasted {
            snap(layout)
        }
    }

    private func snap(_ layout: GlobeLayout) {
        let camera = movement.camera(at: .now)
        let beneath = code(at: layout.centre, camera: camera, layout: layout)
        let nearby = GlobeMotion.nearby(world.anchors, projection: layout.projection(camera))
        guard let target = GlobeMotion.snapTarget(beneath: beneath, nearby: nearby) else { return }
        snaps += 1
        fly(to: target, duration: GlobeMovement.snapDuration)
    }

    private func drag(_ layout: GlobeLayout) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !isPinching, unroll == 0 else { return }
                let camera = movement.camera(at: .now)
                let from = lastDrag ?? value.startLocation
                isDragging = true
                focus = nil
                movement = .resting(GlobeMotion.drag(
                    camera,
                    from: from,
                    to: value.location,
                    centre: layout.centre,
                    radius: layout.radius,
                ))
                lastDrag = value.location
            }
            .onEnded { value in
                guard isDragging else { return }
                lastDrag = nil
                isDragging = false
                let camera = movement.camera(at: .now)
                // Reduce Motion: no inertia, the globe stops where the finger lifts.
                let spin = reduceMotion ? .zero : GlobeMotion.spin(
                    fromVelocity: value.velocity,
                    camera: camera,
                    radius: layout.radius,
                )
                if GlobeMotion.coastDuration(spin) > 0.05 {
                    movement = .coasting(from: camera, spin: spin, start: .now)
                } else {
                    movement = .resting(camera)
                    snap(layout)
                }
            }
    }

    /// A double tap stamps the country under it; a single tap flies there.
    private func taps(_ layout: GlobeLayout) -> some Gesture {
        SpatialTapGesture(count: 2)
            .exclusively(before: SpatialTapGesture())
            .onEnded { value in
                guard unroll == 0 else { return }
                let camera = movement.camera(at: .now)
                switch value {
                case let .first(tap):
                    if let code = code(at: tap.location, camera: camera, layout: layout) {
                        onStamp(code)
                    }
                case let .second(tap):
                    if let code = code(at: tap.location, camera: camera, layout: layout) {
                        fly(to: code)
                    }
                }
            }
    }

    /// Pinching in unrolls the globe into the flat map, following the fingers.
    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                isPinching = true
                guard !reduceMotion else { return }
                unroll = GlobeMotion.unrollProgress(magnification: value.magnification)
            }
            .onEnded { value in
                isPinching = false
                if GlobeMotion.unrollCommits(magnification: value.magnification, reduceMotion: reduceMotion) {
                    finishUnroll()
                } else {
                    withAnimation(Motion.morph) { unroll = 0 }
                }
            }
    }

    private func finishUnroll() {
        guard !reduceMotion else {
            onUnrolled()
            return
        }
        withAnimation(.easeInOut(duration: GlobeMotion.unrollDuration)) {
            unroll = 1
        } completion: {
            onUnrolled()
        }
    }
}

/// The globe's Canvas: animatable in the unroll and the bloom, so both run smoothly.
private struct GlobeCanvas: View, Animatable {
    let camera: GlobeCamera
    let moving: Bool
    let visited: Set<String>
    let bloom: String?
    var unroll: Double
    var bloomProgress: Double
    let reduceMotion: Bool

    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(unroll, bloomProgress) }
        set {
            unroll = newValue.first
            bloomProgress = newValue.second
        }
    }

    var body: some View {
        Canvas { context, size in
            let layout = GlobeLayout(size: size)
            let morphing = unroll > 0
            let renderer = GlobeRenderer(projection: layout.projection(camera), moving: moving || morphing)
            let inked = bloom.map { visited.subtracting([$0]) } ?? visited
            if morphing {
                renderer.drawUnrolling(in: context, mapRect: layout.mapRect, progress: min(unroll, 1), visited: visited)
                return
            }
            renderer.draw(in: context, visited: inked)
            if let bloom {
                renderer.drawBloom(in: context, code: bloom, progress: bloomProgress, reduceMotion: reduceMotion)
            }
        }
    }
}
