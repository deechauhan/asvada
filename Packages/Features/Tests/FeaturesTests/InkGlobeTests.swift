import CoreGraphics
import Foundation
import Geo
import SwiftUI
import Testing
@testable import Features

@MainActor
struct InkGlobeTests {
    private let centre = CGPoint(x: 200, y: 200)
    private let radius = 100.0

    private func projection(_ longitude: Double, _ latitude: Double) -> GlobeProjection {
        GlobeProjection(camera: GlobeCamera(longitude: longitude, latitude: latitude), centre: centre, radius: radius)
    }

    private func near(_ first: Double, _ second: Double, within tolerance: Double = 1e-6) -> Bool {
        abs(first - second) <= tolerance
    }

    // MARK: - Camera and projection

    @Test func theCameraClampsLatitudeAndWrapsLongitude() {
        let camera = GlobeCamera(longitude: 190, latitude: 89)
        #expect(near(camera.longitude, -170))
        #expect(camera.latitude == GlobeCamera.latitudes.upperBound)
        #expect(GlobeCamera(longitude: -540, latitude: -80).latitude == GlobeCamera.latitudes.lowerBound)
        #expect(near(GlobeCamera(longitude: -540, latitude: 0).longitude, -180))
    }

    @Test func theMiddleOfTheCameraIsTheMiddleOfTheDisc() throws {
        let globe = projection(30, 40)
        let middle = try #require(globe.screen(of: GeoPoint(longitude: 30, latitude: 40)))
        #expect(near(middle.x, centre.x) && near(middle.y, centre.y))
        // North is up, east is right.
        let north = try #require(globe.screen(of: GeoPoint(longitude: 30, latitude: 50)))
        let east = try #require(globe.screen(of: GeoPoint(longitude: 40, latitude: 40)))
        #expect(north.y < centre.y)
        #expect(east.x > centre.x)
        // The far side is hidden, and is straight through the middle.
        #expect(globe.screen(of: GeoPoint(longitude: -150, latitude: -40)) == nil)
        #expect(near(globe.farSide.longitude, -150) && near(globe.farSide.latitude, -40))
    }

    @Test func aPointOnScreenTurnsBackIntoThePlaceUnderIt() throws {
        let globe = projection(-60, -20)
        for place in [
            GeoPoint(longitude: -60, latitude: -20),
            GeoPoint(longitude: -30, latitude: 10),
            GeoPoint(longitude: -95, latitude: -45),
        ] {
            let point = try #require(globe.screen(of: place))
            let back = try #require(globe.geoPoint(at: point))
            #expect(near(back.longitude, place.longitude, within: 1e-6) && near(back.latitude, place.latitude, within: 1e-6))
        }
        #expect(globe.geoPoint(at: CGPoint(x: 200, y: 50)) == nil)
    }

    @Test func thePlaceUnderTheRingIsFoundOnTheFlatMap() throws {
        let globe = projection(2.35, 48.85)
        let place = try #require(globe.geoPoint(at: centre))
        #expect(InkWorld.shared.code(atUnit: InkWorld.shared.unit(place)) == "FR")
    }

    // MARK: - Dragging and coasting

    @Test func draggingRightTurnsTheWestIntoViewAndDownTurnsTheNorth() {
        let camera = GlobeCamera(longitude: 0, latitude: 0)
        let right = GlobeMotion.drag(camera, from: centre, to: CGPoint(x: 220, y: 200), centre: centre, radius: radius)
        let down = GlobeMotion.drag(camera, from: centre, to: CGPoint(x: 200, y: 220), centre: centre, radius: radius)
        #expect(right.longitude < 0 && near(right.latitude, 0))
        #expect(down.latitude > 0 && near(down.longitude, 0))
    }

    @Test func thePlaceUnderTheFingerStaysUnderIt() throws {
        let camera = GlobeCamera(longitude: 10, latitude: 20)
        let from = CGPoint(x: 230, y: 180)
        let finish = CGPoint(x: 250, y: 190)
        let before = try #require(projection(10, 20).geoPoint(at: from))
        let moved = GlobeMotion.drag(camera, from: from, to: finish, centre: centre, radius: radius)
        let after = try #require(GlobeProjection(camera: moved, centre: centre, radius: radius).geoPoint(at: finish))
        #expect(near(after.longitude, before.longitude, within: 1e-4))
        #expect(near(after.latitude, before.latitude, within: 1e-4))
    }

    @Test func draggingNeverTurnsPastTheLatitudeClamp() {
        var camera = GlobeCamera(longitude: 0, latitude: 60)
        for _ in 0 ..< 20 {
            camera = GlobeMotion.drag(camera, from: centre, to: CGPoint(x: 200, y: 240), centre: centre, radius: radius)
        }
        #expect(camera.latitude == GlobeCamera.latitudes.upperBound)
    }

    @Test func aFlingCoastsAndDecays() {
        let camera = GlobeCamera(longitude: 0, latitude: 0)
        let spin = GlobeMotion.spin(fromVelocity: CGSize(width: -300, height: 0), camera: camera, radius: radius)
        // A fling to the left turns the east into view.
        #expect(spin.longitude > 0 && spin.latitude == 0)
        let early = GlobeMotion.coast(camera, spin: spin, elapsed: 0.1)
        let late = GlobeMotion.coast(camera, spin: spin, elapsed: 0.2)
        // The second tenth of a second travels e^(−0.24) as far as the first.
        let ratio = (late.longitude - early.longitude) / early.longitude
        #expect(near(ratio, exp(-GlobeMotion.decay * 0.1), within: 1e-9))
        // It stops once it's slower than the rest speed.
        let duration = GlobeMotion.coastDuration(spin)
        #expect(near(spin.speed * exp(-GlobeMotion.decay * duration), GlobeMotion.restSpeed, within: 1e-9))
        #expect(GlobeMotion.coastDuration(GlobeSpin(longitude: 1, latitude: 0)) == 0)
    }

    @Test func aWildFlingIsCapped() {
        let spin = GlobeMotion.spin(fromVelocity: CGSize(width: 90000, height: 0), camera: GlobeCamera(), radius: radius)
        #expect(near(spin.speed, GlobeMotion.maxSpeed))
    }

    // MARK: - Movement

    @Test func aFlightEasesTheShortWayRound() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let movement = GlobeMovement.flight(
            from: .resting(GlobeCamera(longitude: 170, latitude: 0)),
            to: GlobeCamera(longitude: -170, latitude: 10),
            at: start,
            reduceMotion: false,
        )
        #expect(movement.isMoving)
        #expect(movement.camera(at: start) == GlobeCamera(longitude: 170, latitude: 0))
        let halfway = movement.camera(at: start.addingTimeInterval(GlobeMovement.flightDuration / 2))
        #expect(near(abs(halfway.longitude), 180) && near(halfway.latitude, 5))
        #expect(movement.camera(at: start.addingTimeInterval(5)) == GlobeCamera(longitude: -170, latitude: 10))
        #expect(movement.end == start.addingTimeInterval(GlobeMovement.flightDuration))
    }

    @Test func reduceMotionCutsInsteadOfFlying() {
        let target = GlobeCamera(longitude: 139, latitude: 36)
        let movement = GlobeMovement.flight(from: .resting(GlobeCamera()), to: target, at: .now, reduceMotion: true)
        #expect(movement == .resting(target))
        #expect(!movement.isMoving)
    }

    @Test func aCoastEndsWhereItStops() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let spin = GlobeSpin(longitude: 120, latitude: 0)
        let movement = GlobeMovement.coasting(from: GlobeCamera(longitude: 0, latitude: 0), spin: spin, start: start)
        #expect(movement.isCoasting)
        #expect(movement.camera(at: start.addingTimeInterval(60)) == movement.destination)
        #expect(movement.end == start.addingTimeInterval(GlobeMotion.coastDuration(spin)))
    }

    @Test func flyingToACountryFacesItsMiddle() throws {
        let movement = try #require(GlobeMovement.flight(
            from: .resting(GlobeCamera()),
            toCountry: "jp",
            at: .now,
            reduceMotion: true,
        ))
        let anchor = try #require(InkGlobeWorld.shared.country(code: "JP")).anchor.point
        #expect(movement == .resting(GlobeCamera(facing: anchor)))
        #expect(GlobeMovement.flight(from: .resting(GlobeCamera()), toCountry: "AQ", at: .now, reduceMotion: true) == nil)
    }

    // MARK: - Magnet and chips

    @Test func onlyMiddlesNearTheRingAndFacingYouAreNearby() {
        let globe = projection(0, 0)
        let anchors = [
            GlobeAnchor(code: "FAR", point: GeoPoint(longitude: 180, latitude: 0)),
            GlobeAnchor(code: "OUT", point: GeoPoint(longitude: 40, latitude: 0)),
            GlobeAnchor(code: "TWO", point: GeoPoint(longitude: 10, latitude: 0)),
            GlobeAnchor(code: "ONE", point: GeoPoint(longitude: 0, latitude: 5)),
        ]
        #expect(GlobeMotion.nearby(anchors, projection: globe) == ["ONE", "TWO"])
    }

    @Test func theMagnetPullsTheNearestMiddleUnlessABigCountryIsBeneath() {
        #expect(GlobeMotion.snapTarget(beneath: "BE", nearby: ["LU", "BE"]) == "BE")
        #expect(GlobeMotion.snapTarget(beneath: nil, nearby: ["LU", "BE"]) == "LU")
        #expect(GlobeMotion.snapTarget(beneath: "RU", nearby: ["EE"]) == nil)
        #expect(GlobeMotion.snapTarget(beneath: nil, nearby: []) == nil)
    }

    @Test func chipsOnlyShowWhenASmallNeighbourIsNear() {
        let small: (String) -> Bool = { $0 == "LU" }
        #expect(GlobeMotion.chips(aimed: "BE", nearby: ["LU", "BE", "NL"], isSmall: small) == ["BE", "LU", "NL"])
        #expect(GlobeMotion.chips(aimed: "FR", nearby: ["FR", "ES"], isSmall: small).isEmpty)
        #expect(GlobeMotion.chips(aimed: "LU", nearby: ["LU"], isSmall: small).isEmpty)
        #expect(GlobeMotion.chips(aimed: nil, nearby: ["A", "B", "C", "D", "LU"], isSmall: small).isEmpty)
    }

    // MARK: - The world and its outlines

    @Test func theGlobeHoldsEveryCountryButAntarctica() throws {
        let world = InkGlobeWorld.shared
        #expect(world.country(code: "AQ") == nil)
        #expect(world.countries.allSatisfy { !$0.rings.isEmpty })
        // The United States is aimed at the lower 48.
        let usa = try #require(world.country(code: "US")).anchor.point
        #expect((-125 ... -66).contains(usa.longitude) && (24 ... 50).contains(usa.latitude))
        #expect(try #require(world.country(code: "LU")).isSmall)
        #expect(try !#require(world.country(code: "RU")).isSmall)
    }

    @Test func thinningDropsNearbyPointsButKeepsAShape() {
        let dense = (0 ..< 20).map { GlobeSphere.vector(GeoPoint(longitude: Double($0) * 0.01, latitude: 0)) }
        #expect(InkGlobeWorld.thin(dense, step: 0.3).count == 3)
        let spaced = (0 ..< 10).map { GlobeSphere.vector(GeoPoint(longitude: Double($0), latitude: 0)) }
        #expect(InkGlobeWorld.thin(spaced, step: 0.3).count == 10)
        #expect(InkGlobeWorld.thin(spaced, step: 2.5).count == 4)
    }

    @Test func countriesRoundTheBackAreNotDrawn() {
        let renderer = GlobeRenderer(projection: projection(0, 0), moving: false)
        let world = InkGlobeWorld.shared
        #expect(world.country(code: "JP").flatMap { renderer.outline($0) } == nil)
        #expect(world.country(code: "FR").flatMap { renderer.outline($0) } != nil)
    }

    @Test func outlinesStayOnTheBall() throws {
        let renderer = GlobeRenderer(projection: projection(60, 30), moving: false)
        // Russia straddles the horizon from here.
        let russia = try #require(InkGlobeWorld.shared.country(code: "RU").flatMap { renderer.outline($0) })
        #expect(renderer.disc.insetBy(dx: -0.5, dy: -0.5).contains(russia.boundingRect))
    }

    @Test func aStraddlingOutlineFillsOnlyItsFront() throws {
        let renderer = GlobeRenderer(projection: projection(180, 0), moving: false)
        let ring = try #require(InkGlobeWorld.ring(box(west: 60, east: 120, south: -20, north: 20), flat: .shared))
        let path = try #require(renderer.outline(ring))
        let front = try #require(projection(180, 0).screen(of: GeoPoint(longitude: 110, latitude: 0)))
        #expect(path.contains(front, eoFill: true))
        #expect(!path.contains(centre, eoFill: true))
    }

    @Test func anOutlineHoldingTheFarSideIsTurnedInsideOut() throws {
        // The box holds 0°, 0°, the far side of a globe facing 180°: only its edges near the rim show.
        let globe = projection(180, 0)
        let renderer = GlobeRenderer(projection: globe, moving: false)
        let ring = try #require(InkGlobeWorld.ring(box(west: -100, east: 100, south: -50, north: 50), flat: .shared))
        let path = try #require(renderer.outline(ring))
        #expect(!path.contains(centre, eoFill: true))
        #expect(try path.contains(#require(globe.screen(of: GeoPoint(longitude: 95, latitude: 0))), eoFill: true))
        #expect(try path.contains(#require(globe.screen(of: GeoPoint(longitude: -95, latitude: 10))), eoFill: true))
        #expect(try !path.contains(#require(globe.screen(of: GeoPoint(longitude: 150, latitude: 0))), eoFill: true))
    }

    // MARK: - Unrolling

    @Test func pinchingInUnrollsTheGlobe() {
        #expect(GlobeMotion.unrollProgress(magnification: 1) == 0)
        #expect(near(GlobeMotion.unrollProgress(magnification: 0.75), 0.5))
        #expect(GlobeMotion.unrollProgress(magnification: 0.2) == 1)
        #expect(GlobeMotion.unrollProgress(magnification: 1.5) == 0)
        #expect(GlobeMotion.unrollCommits(magnification: 0.7, reduceMotion: false))
        #expect(!GlobeMotion.unrollCommits(magnification: 0.9, reduceMotion: false))
        #expect(GlobeMotion.unrollCommits(magnification: 0.75, reduceMotion: true))
    }

    @Test func theFrameEasesFromTheGlobeToTheFlatMap() {
        let flat = InkWorld.shared.aspectRatio
        #expect(GlobeLayout.aspect(unroll: 0) == GlobeLayout.globeAspect)
        #expect(abs(GlobeLayout.aspect(unroll: 1) - flat) < 1e-9)
        let layout = GlobeLayout(size: CGSize(width: 390, height: 390 / flat))
        #expect(abs(layout.mapRect.minY) < 1e-9 && abs(layout.mapRect.height - layout.size.height) < 1e-9)
    }

    /// A box outline with a point every 5°, so its edges follow the sphere.
    private func box(west: Double, east: Double, south: Double, north: Double) -> [GeoPoint] {
        var points: [GeoPoint] = []
        for longitude in stride(from: west, to: east, by: 5) {
            points.append(GeoPoint(longitude: longitude, latitude: south))
        }
        for latitude in stride(from: south, to: north, by: 5) {
            points.append(GeoPoint(longitude: east, latitude: latitude))
        }
        for longitude in stride(from: east, to: west, by: -5) {
            points.append(GeoPoint(longitude: longitude, latitude: north))
        }
        for latitude in stride(from: north, to: south, by: -5) {
            points.append(GeoPoint(longitude: west, latitude: latitude))
        }
        return points
    }
}
