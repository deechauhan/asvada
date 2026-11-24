import DesignSystem
import Geo
import SwiftUI

/// The rubber stamp resting in the map's corner. Carry it over the map and lift to stamp; tap it
/// to stamp wherever the reticle is. VoiceOver: a button that stamps the aimed country.
struct RubberStampHandle: View {
    let isLifted: Bool
    /// The country the reticle is on, if any.
    let aimed: String?
    let onStamp: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // The knob…
            Capsule()
                .fill(Palette.brand.color)
                .frame(width: 16, height: 18)
            // …and the rubber foot, inked plum.
            RoundedRectangle(cornerRadius: 4)
                .fill(Palette.textPrimary.color.opacity(0.85))
                .frame(width: 34, height: 10)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Palette.brand.color)
                        .frame(height: 3)
                }
        }
        .frame(width: 52, height: 52)
        .glassEffect(.regular.interactive(), in: Circle())
        .scaleEffect(isLifted ? 1.15 : 1)
        .shadow(color: Palette.textPrimary.color.opacity(isLifted ? 0.3 : 0.12), radius: isLifted ? 10 : 4, y: isLifted ? 8 : 2)
        .animation(Motion.pull, value: isLifted)
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Rubber stamp")
        .accessibilityValue(aimed.map { "Aimed at \($0)" } ?? "Not aimed")
        .accessibilityHint("Drag it over the map and lift to stamp the country under it, or tap to stamp where the reticle is")
        .accessibilityAction { onStamp() }
        .accessibilityIdentifier("rubberStamp")
    }
}

/// The dashed ring where the stamp will land, locked on a country, with its name on glass.
struct StampReticle: View {
    let label: String

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Circle()
                .strokeBorder(Palette.brand.color, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                .frame(width: 30, height: 30)
            Text(label)
                .typeToken(.caption)
                .foregroundStyle(Palette.textPrimary.color)
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.xxs)
                .glassEffect(.regular, in: Capsule())
                .fixedSize()
        }
        // The ring, not the label, sits on the point.
        .offset(y: 12)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aimed at \(label)")
        .accessibilityIdentifier("stampReticle")
    }
}

/// The 2× loupe over the stamp's foot: the countries under it, the one it'll stamp named below.
struct StampLoupe: View {
    let centre: CGPoint?
    let mapSize: CGSize
    let stamped: Set<String>
    let label: String?

    var body: some View {
        let diameter = StampPadLogic.loupeDiameter
        VStack(spacing: Spacing.xxs) {
            Canvas { context, _ in
                guard let centre else { return }
                let transform = StampPadLogic.loupeTransform(centre: centre, mapSize: mapSize, diameter: diameter)
                InkWorld.shared.draw(in: context, transform: transform, visited: stamped)
            }
            .frame(width: diameter, height: diameter)
            .background(Palette.background.color)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(Palette.brand.color.opacity(0.6), lineWidth: 2)
                Circle()
                    .strokeBorder(Palette.brand.color, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: 26, height: 26)
            }
            .shadow(color: Palette.textPrimary.color.opacity(0.25), radius: 8, y: 4)
            Text(label ?? "Open sea")
                .typeToken(.caption)
                .foregroundStyle(label == nil ? Palette.textSecondary.color : Palette.textPrimary.color)
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.xxs)
                .glassEffect(.regular, in: Capsule())
                .fixedSize()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A stamp landing on the map: the rubber's ring thunks onto the impact point, then ink floods
/// the country outwards from it while a fainter ring spreads and fades. A plain fade under
/// Reduce Motion. Calls `onDone` when the ink has settled.
struct InkBloomLayer: View {
    let bloom: InkBloom
    let onDone: () -> Void
    @State private var progress = 0.0
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BloomCanvas(bloom: bloom, progress: progress, reduceMotion: reduceMotion)
                if !reduceMotion {
                    Circle()
                        .strokeBorder(Palette.brand.color, lineWidth: 2.5)
                        .frame(width: 30, height: 30)
                        .opacity(1 - progress)
                        .thunk(trigger: landed)
                        .position(x: bloom.origin.x * proxy.size.width, y: bloom.origin.y * proxy.size.height)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            landed = true
            withAnimation(reduceMotion ? Motion.inkBloomFill : Motion.inkBloomRing) {
                progress = 1
            } completion: {
                onDone()
            }
        }
    }
}

/// The bloom's ink, drawn at `progress` (0…1); animatable so the spread is smooth.
private struct BloomCanvas: View, Animatable {
    let bloom: InkBloom
    var progress: Double
    let reduceMotion: Bool

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            guard let shape = InkWorld.shared.shape(code: bloom.code) else { return }
            let path = shape.path.applying(CGAffineTransform(scaleX: size.width, y: size.height))
            let ink = Palette.brand.color
            if reduceMotion {
                context.opacity = progress
                context.fill(path, with: .color(ink))
                return
            }
            let origin = CGPoint(x: bloom.origin.x * size.width, y: bloom.origin.y * size.height)
            let box = path.boundingRect
            let reach = [
                CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
                CGPoint(x: box.minX, y: box.maxY), CGPoint(x: box.maxX, y: box.maxY),
            ]
            .map { hypot($0.x - origin.x, $0.y - origin.y) }
            .max() ?? 0
            // The fill reaches every corner a little over halfway through; the ring keeps going.
            let fill = reach * min(progress / 0.55, 1)
            var flooded = context
            flooded.clip(to: Path(ellipseIn: CGRect(x: origin.x - fill, y: origin.y - fill, width: fill * 2, height: fill * 2)))
            flooded.fill(path, with: .color(ink))
            let ring = max(reach, 20) * 1.5 * progress
            context.stroke(
                Path(ellipseIn: CGRect(x: origin.x - ring, y: origin.y - ring, width: ring * 2, height: ring * 2)),
                with: .color(ink.opacity(0.5 * (1 - progress))),
                lineWidth: 2,
            )
        }
    }
}

/// "All" plus one chip per continent; choosing one deals that continent's strip.
struct StampContinentChips: View {
    @Binding var selection: Continent?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.small) {
                chip("All", isOn: selection == nil) { selection = nil }
                ForEach(Continent.allCases.filter { $0 != .antarctica }, id: \.self) { continent in
                    chip(continent.name, isOn: selection == continent) { selection = continent }
                }
            }
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .typeToken(.callout)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
                .foregroundStyle(isOn ? Palette.onBrand.color : Palette.textPrimary.color)
                .background(isOn ? Palette.brand.color : Palette.surface.color, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("continent-\(title)")
    }
}

/// A strip of stamps to tap through: dashed outlines still to stamp, inked ones already stamped
/// (tap again to wash off). The quick path, and VoiceOver's.
struct StampStrip: View {
    let title: String
    let countries: [Country]
    let stamped: Set<String>
    let onStamp: (String) -> Void
    let onWashOff: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title)
                .font(.system(.footnote, design: .serif).italic())
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityIdentifier("stampStripTitle")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.small) {
                    ForEach(countries) { country in
                        StripStamp(country: country, isStamped: stamped.contains(country.code)) {
                            if stamped.contains(country.code) {
                                onWashOff(country.code)
                            } else {
                                onStamp(country.code)
                            }
                        }
                    }
                }
                .padding(.vertical, Spacing.xxs)
            }
        }
    }
}

/// One stamp in the strip: a dashed outline until it's stamped, then inked plum.
private struct StripStamp: View {
    let country: Country
    let isStamped: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Text(country.flag)
                    .font(.title3)
                Text(country.name)
                    .typeToken(.ticketLabel)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isStamped ? Palette.brand.color : Palette.textSecondary.color)
            .frame(width: 84, height: 70)
            .background(
                isStamped ? Palette.brand.color.opacity(0.1) : Color.clear,
                in: RoundedRectangle(cornerRadius: Radius.small),
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.small)
                    .strokeBorder(
                        Palette.brand.color.opacity(isStamped ? 0.9 : 0.4),
                        style: StrokeStyle(lineWidth: isStamped ? 2 : 1.2, dash: isStamped ? [] : [5, 4]),
                    )
            }
            .rotationEffect(.degrees(isStamped ? Tilt.degrees(for: country.code, max: Tilt.stampMax) : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(country.name)
        .accessibilityAddTraits(isStamped ? .isSelected : [])
        .accessibilityHint(isStamped ? "Stamped. Activate to wash it off" : "Activate to stamp")
        .accessibilityIdentifier("stamp-\(country.code)")
    }
}

/// The passport so far, newest first. The newest thunks in; long-press any to wash it off.
struct PassportStrip: View {
    let codes: [String]
    let latest: String?
    let onWashOff: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(codes, id: \.self) { code in
                    if let country = CountryCatalog.shared.country(code: code) {
                        PassportStripStamp(country: country, isLatest: code == latest, onWashOff: { onWashOff(code) })
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
        .accessibilityIdentifier("passportStrip")
    }
}

private struct PassportStripStamp: View {
    let country: Country
    let isLatest: Bool
    let onWashOff: () -> Void

    var body: some View {
        let stamp = PassportStamp(country: country.name, code: country.code)
            .scaleEffect(0.62)
            .frame(width: 96, height: 72)
        Group {
            if isLatest {
                ThunkOnAppear { stamp }
            } else {
                stamp
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5, perform: onWashOff)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Passport stamp, \(country.name)")
        .accessibilityAction(named: "Wash off", onWashOff)
        .accessibilityIdentifier("passport-\(country.code)")
    }
}

/// Lands its content with the thunk once, when it appears.
private struct ThunkOnAppear<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var landed = false

    var body: some View {
        content
            .thunk(trigger: landed)
            .onAppear { landed = true }
    }
}

/// "Washed off Japan · Undo", for five seconds after a long-press.
struct WashOffBar: View {
    let country: String
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text("Washed off \(country)")
                .typeToken(.callout)
                .foregroundStyle(Palette.textPrimary.color)
            Spacer(minLength: Spacing.small)
            Button("Undo", action: onUndo)
                .typeToken(.headline)
                .accessibilityIdentifier("washOffUndo")
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.medium)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .contain)
    }
}
