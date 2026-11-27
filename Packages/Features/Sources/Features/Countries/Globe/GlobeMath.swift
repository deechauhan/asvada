import CoreGraphics
import Foundation
import Geo
import simd

/// Which way the ink globe faces: the longitude and latitude at its middle. North stays up, so
/// there's no roll, and the latitude is clamped so a pole never faces you square on
/// (docs/design/INTERACTION.md §6).
struct GlobeCamera: Equatable {
    static let latitudes = -65.0 ... 75.0

    let longitude: Double
    let latitude: Double

    init(longitude: Double = 10, latitude: Double = 30) {
        self.longitude = Self.wrap(longitude)
        self.latitude = min(max(latitude, Self.latitudes.lowerBound), Self.latitudes.upperBound)
    }

    init(facing point: GeoPoint) {
        self.init(longitude: point.longitude, latitude: point.latitude)
    }

    /// The point at the globe's middle, under the reticle.
    var centre: GeoPoint {
        GeoPoint(longitude: longitude, latitude: latitude)
    }

    /// Turns world vectors into the view: the middle comes round to +z (towards you), north up +y.
    var rotation: simd_quatd {
        let pitch = simd_quatd(angle: latitude * .pi / 180, axis: SIMD3(1, 0, 0))
        let yaw = simd_quatd(angle: -longitude * .pi / 180, axis: SIMD3(0, 1, 0))
        return pitch * yaw
    }

    /// `longitude` brought into -180..<180.
    static func wrap(_ longitude: Double) -> Double {
        var value = longitude.truncatingRemainder(dividingBy: 360)
        if value >= 180 {
            value -= 360
        } else if value < -180 {
            value += 360
        }
        return value
    }
}

/// Points on the unit sphere: x east at the prime meridian's equator, y north, z out of 0°, 0°.
enum GlobeSphere {
    static func vector(_ point: GeoPoint) -> SIMD3<Double> {
        let longitude = point.longitude * .pi / 180
        let latitude = point.latitude * .pi / 180
        return SIMD3(cos(latitude) * sin(longitude), sin(latitude), cos(latitude) * cos(longitude))
    }

    static func point(_ vector: SIMD3<Double>) -> GeoPoint {
        let unit = simd_normalize(vector)
        return GeoPoint(
            longitude: atan2(unit.x, unit.z) * 180 / .pi,
            latitude: asin(min(max(unit.y, -1), 1)) * 180 / .pi,
        )
    }

    /// The angle between two unit vectors, in degrees.
    static func degrees(between first: SIMD3<Double>, and second: SIMD3<Double>) -> Double {
        acos(min(max(simd_dot(first, second), -1), 1)) * 180 / .pi
    }
}

/// The orthographic projection of the globe into a view: a disc of `radius` points about `centre`.
struct GlobeProjection {
    let camera: GlobeCamera
    let centre: CGPoint
    let radius: Double
    let rotation: simd_quatd

    init(camera: GlobeCamera, centre: CGPoint, radius: Double) {
        self.camera = camera
        self.centre = centre
        self.radius = radius
        rotation = camera.rotation
    }

    /// A world vector turned into the view; z > 0 is the hemisphere facing you.
    func view(_ world: SIMD3<Double>) -> SIMD3<Double> {
        rotation.act(world)
    }

    /// Where a view vector lands on screen (its depth ignored).
    func screen(_ view: SIMD3<Double>) -> CGPoint {
        CGPoint(x: centre.x + view.x * radius, y: centre.y - view.y * radius)
    }

    /// Where a hidden view vector shows: pushed out to the rim, which is how horizon clipping
    /// draws the part of a country round the back.
    func limb(_ view: SIMD3<Double>) -> CGPoint {
        let length = hypot(view.x, view.y)
        guard length > 1e-9 else { return CGPoint(x: centre.x + radius, y: centre.y) }
        return CGPoint(x: centre.x + view.x / length * radius, y: centre.y - view.y / length * radius)
    }

    /// Where `point` shows on screen, or nil when it's round the back.
    func screen(of point: GeoPoint) -> CGPoint? {
        let view = view(GlobeSphere.vector(point))
        return view.z > 0 ? screen(view) : nil
    }

    /// The view vector under a screen point, or nil off the disc unless `clampToRim`.
    func viewVector(at point: CGPoint, clampToRim: Bool = false) -> SIMD3<Double>? {
        guard radius > 0 else { return nil }
        var x = Double(point.x - centre.x) / radius
        var y = Double(centre.y - point.y) / radius
        let squared = x * x + y * y
        if squared > 1 {
            guard clampToRim else { return nil }
            let length = squared.squareRoot()
            x /= length
            y /= length
            return SIMD3(x, y, 0)
        }
        return SIMD3(x, y, (1 - squared).squareRoot())
    }

    /// The place under a screen point, or nil off the globe.
    func geoPoint(at point: CGPoint) -> GeoPoint? {
        viewVector(at: point).map { GlobeSphere.point(rotation.inverse.act($0)) }
    }

    /// The point on the far side, straight through the middle.
    var farSide: GeoPoint {
        GlobeSphere.point(rotation.inverse.act(SIMD3(0, 0, -1)))
    }
}

/// How fast the globe is turning after a fling, in degrees per second.
struct GlobeSpin: Equatable {
    var longitude: Double
    var latitude: Double

    static let zero = GlobeSpin(longitude: 0, latitude: 0)

    var speed: Double {
        hypot(longitude, latitude)
    }
}

/// Spinning, coasting and snapping, kept out of the view so it's unit-tested.
enum GlobeMotion {
    /// The coast decays as e^(−2.4t).
    static let decay = 2.4
    /// Below this (degrees per second) the globe has stopped and the magnet takes over.
    static let restSpeed = 3.0
    /// A fling never starts faster than this, so the world stays readable.
    static let maxSpeed = 540.0
    /// A country's middle this close to the ring (in points) snaps into it.
    static let snapRadius: CGFloat = 46

    /// A pinch closing this far (to half size) unrolls the globe all the way.
    static let unrollPinch = 0.5
    /// Let go past this much of the unroll and it finishes; before it, it rolls back up.
    static let unrollCommit = 0.35
    /// The unroll morph, start to finish.
    static let unrollDuration = 0.6

    /// How far a pinch at `magnification` has unrolled the globe (0 globe, 1 flat).
    static func unrollProgress(magnification: Double) -> Double {
        min(max((1 - magnification) / unrollPinch, 0), 1)
    }

    /// Whether letting go of the pinch finishes the unroll. Under Reduce Motion there's no
    /// morph to follow the fingers, so a clear pinch in is enough.
    static func unrollCommits(magnification: Double, reduceMotion: Bool) -> Bool {
        reduceMotion ? magnification < 0.8 : unrollProgress(magnification: magnification) > unrollCommit
    }

    /// Pinning works out to here (a fraction of the radius); nearer the rim a small move of the
    /// finger is a big turn, and the versor turn is steadier.
    static let pinReach = 0.8
    /// A pinned step that would turn the globe further than this (degrees) uses the versor turn.
    static let pinLimit = 25.0

    /// Dragging: the camera once the finger has moved from `start` to `finish`. The place under the
    /// finger stays under it: solved exactly for a north-up camera where it can be, else a versor
    /// (quaternion) turn from one point to the other, which never gimbal-locks. Either way the
    /// camera keeps north up and clamps the latitude.
    static func drag(
        _ camera: GlobeCamera,
        from start: CGPoint,
        to finish: CGPoint,
        centre: CGPoint,
        radius: Double,
    ) -> GlobeCamera {
        let projection = GlobeProjection(camera: camera, centre: centre, radius: radius)
        guard let from = projection.viewVector(at: start, clampToRim: true),
              let end = projection.viewVector(at: finish, clampToRim: true),
              simd_distance(from, end) > 1e-9
        else { return camera }
        if hypot(from.x, from.y) <= pinReach,
           let place = projection.geoPoint(at: start),
           let pin = pinned(camera, place: place, at: end),
           abs(GlobeCamera.wrap(pin.longitude - camera.longitude)) <= pinLimit,
           abs(pin.latitude - camera.latitude) <= pinLimit
        {
            return pin
        }
        let turn = simd_quatd(from: simd_normalize(from), to: simd_normalize(end))
        let middle = (turn * projection.rotation).inverse.act(SIMD3(0, 0, 1))
        return GlobeCamera(facing: GlobeSphere.point(middle))
    }

    /// The north-up camera nearest `camera` that shows `place` at view vector `view`, or nil if
    /// none can. With the camera at longitude λ₀ and latitude φ₀, the place (λ, φ) lands at
    /// x = cos φ sin(λ − λ₀) and y = sin φ cos φ₀ − cos φ cos(λ − λ₀) sin φ₀.
    static func pinned(_ camera: GlobeCamera, place: GeoPoint, at view: SIMD3<Double>) -> GlobeCamera? {
        let longitude = place.longitude * .pi / 180
        let latitude = place.latitude * .pi / 180
        let across = cos(latitude)
        guard across > 1e-6, abs(view.x / across) <= 1 else { return nil }
        let turn = asin(view.x / across)
        var best: (cost: Double, camera: GlobeCamera)?
        for offset in [turn, .pi - turn] {
            // y = A cos φ₀ − B sin φ₀ = ρ cos(φ₀ + δ)
            let lift = sin(latitude)
            let depth = across * cos(offset)
            let rho = hypot(lift, depth)
            guard rho > 1e-9, abs(view.y) <= rho else { continue }
            let delta = atan2(depth, lift)
            for sign in [1.0, -1.0] {
                let pitch = remainder(sign * acos(view.y / rho) - delta, 2 * .pi)
                // It has to be on the side facing you, and the camera can't look past a pole.
                guard lift * sin(pitch) + depth * cos(pitch) > 0, abs(pitch) <= .pi / 2 else { continue }
                let candidate = GlobeCamera(longitude: (longitude - offset) * 180 / .pi, latitude: pitch * 180 / .pi)
                let cost = abs(GlobeCamera.wrap(candidate.longitude - camera.longitude)) +
                    abs(candidate.latitude - camera.latitude)
                if best.map({ cost < $0.cost }) ?? true {
                    best = (cost, candidate)
                }
            }
        }
        return best?.camera
    }

    /// The spin a fling leaves, from the finger's velocity in points per second.
    static func spin(fromVelocity velocity: CGSize, camera: GlobeCamera, radius: Double) -> GlobeSpin {
        guard radius > 0 else { return .zero }
        // At the middle, a point of travel turns the globe 1/radius radians.
        let perPoint = 180 / (Double.pi * radius)
        let squeeze = max(cos(camera.latitude * .pi / 180), 0.35)
        var spin = GlobeSpin(longitude: -velocity.width * perPoint / squeeze, latitude: velocity.height * perPoint)
        if spin.speed > maxSpeed {
            let scale = maxSpeed / spin.speed
            spin = GlobeSpin(longitude: spin.longitude * scale, latitude: spin.latitude * scale)
        }
        return spin
    }

    /// Where a coast that began at `camera` with `spin` is after `elapsed` seconds: the travel of
    /// an e^(−2.4t) decay, v(1 − e^(−kt))/k, so it's a pure function of time.
    static func coast(_ camera: GlobeCamera, spin: GlobeSpin, elapsed: Double) -> GlobeCamera {
        let travel = (1 - exp(-decay * max(elapsed, 0))) / decay
        return GlobeCamera(
            longitude: camera.longitude + spin.longitude * travel,
            latitude: camera.latitude + spin.latitude * travel,
        )
    }

    /// How long a coast lasts before it's slow enough to stop (zero if it never got going).
    static func coastDuration(_ spin: GlobeSpin) -> Double {
        guard spin.speed > restSpeed else { return 0 }
        return log(spin.speed / restSpeed) / decay
    }

    /// Countries whose middles are within `snapRadius` of the ring, nearest first. Only those on
    /// the side facing you count.
    static func nearby(_ anchors: [GlobeAnchor], projection: GlobeProjection, within radius: CGFloat = snapRadius) -> [String] {
        anchors
            .compactMap { anchor -> (code: String, distance: CGFloat)? in
                guard let point = projection.screen(of: anchor.point) else { return nil }
                let distance = hypot(point.x - projection.centre.x, point.y - projection.centre.y)
                return distance <= radius ? (anchor.code, distance) : nil
            }
            .sorted { $0.distance < $1.distance }
            .map(\.code)
    }

    /// The country the magnet pulls into the ring once the globe stops: the one beneath it if
    /// its middle is near, the nearest middle when the ring is over the sea, and nothing when
    /// the ring is on a big country whose middle is further off.
    static func snapTarget(beneath: String?, nearby: [String]) -> String? {
        guard let beneath else { return nearby.first }
        return nearby.contains(beneath) ? beneath : nil
    }

    /// The chips that pick between small neighbours ("Luxembourg · Belgium · Netherlands"):
    /// the aimed country and up to three others near the ring, but only when one of them is
    /// small enough to be hard to aim at.
    static func chips(aimed: String?, nearby: [String], isSmall: (String) -> Bool, limit: Int = 4) -> [String] {
        var codes = aimed.map { [$0] } ?? []
        codes += nearby.filter { $0 != aimed }
        codes = Array(codes.prefix(limit))
        guard codes.count > 1, codes.contains(where: isSmall) else { return [] }
        return codes
    }
}

/// Where the reticle aims for a country: the middle of its largest outline.
struct GlobeAnchor: Equatable {
    let code: String
    let point: GeoPoint
}
