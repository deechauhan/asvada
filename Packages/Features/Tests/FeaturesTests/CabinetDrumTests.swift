import Testing
@testable import Features

struct CabinetDrumTests {
    @Test func theFrontDrawerFollowsThePositionAndWraps() {
        #expect(CabinetDrum(count: 7, position: 0).frontIndex == 0)
        #expect(CabinetDrum(count: 7, position: 2.4).frontIndex == 2)
        #expect(CabinetDrum(count: 7, position: 2.6).frontIndex == 3)
        #expect(CabinetDrum(count: 7, position: 7).frontIndex == 0)
        #expect(CabinetDrum(count: 7, position: -1).frontIndex == 6)
        #expect(CabinetDrum(count: 0).frontIndex == 0)
    }

    @Test func offsetsTakeTheShortWayRound() {
        let drum = CabinetDrum(count: 7, position: 0)
        #expect(drum.offset(of: 1) == 1)
        #expect(drum.offset(of: 6) == -1, "the last drawer sits just left of the first")
        #expect(drum.offset(of: 3) == 3)
        #expect(drum.offset(of: 4) == -3)
        let between = CabinetDrum(count: 7, position: 6.5)
        #expect(between.offset(of: 0) == 0.5)
        #expect(between.offset(of: 6) == -0.5)
    }

    @Test func twoDrawersDontWrap() {
        let drum = CabinetDrum(count: 2, position: 0)
        #expect(!drum.wraps)
        #expect(drum.offset(of: 1) == 1)
        // Past the ends the drag stiffens rather than wrapping.
        let pulled = drum.position(dragging: 500, from: 0)
        #expect(pulled < 0 && pulled > -1)
        let pushed = drum.position(dragging: -2000, from: 1)
        #expect(pushed > 1 && pushed < 2)
        #expect(drum.restingPosition(afterReleaseAt: -20000) == 1)
    }

    @Test func dragTracksOneToOne() {
        let drum = CabinetDrum(count: 7)
        #expect(drum.position(dragging: -CabinetDrum.dragPerDrawer, from: 2) == 3, "dragging left brings the next drawer")
        #expect(drum.position(dragging: CabinetDrum.dragPerDrawer / 2, from: 0) == -0.5)
    }

    @Test func releasesLandOnWholeDrawersAtMostThreeAway() {
        var drum = CabinetDrum(count: 7, position: 2.3)
        #expect(drum.restingPosition(afterReleaseAt: 0) == 2)
        drum.position = 2.6
        #expect(drum.restingPosition(afterReleaseAt: 0) == 3)
        drum.position = 2
        // A leftward fling (negative velocity) moves to later drawers.
        #expect(drum.restingPosition(afterReleaseAt: -600) == 4)
        #expect(drum.restingPosition(afterReleaseAt: -50000) == 5)
        #expect(drum.restingPosition(afterReleaseAt: 50000) == -1, "unwrapped: the spring takes the short way")
    }

    @Test func turningToADrawerTakesTheShortWay() {
        let drum = CabinetDrum(count: 7, position: 1)
        #expect(drum.position(turningTo: 3) == 3)
        #expect(drum.position(turningTo: 6) == -1, "6 is two to the left of 1")
        #expect(drum.position(turningTo: 13) == -1, "indices fold")
    }

    @Test func normalisingKeepsTheFrontDrawer() {
        for position in [-15.0, -1, 0, 3, 7, 22] {
            let drum = CabinetDrum(count: 7, position: position)
            let folded = drum.normalised()
            #expect(folded.frontIndex == drum.frontIndex)
            #expect((0 ..< 7.0).contains(folded.position))
        }
    }

    @Test func onlyNearbyDrawersAreDrawnFrontLast() {
        let drum = CabinetDrum(count: 9, position: 0)
        let visible = drum.visibleIndices()
        #expect(Set(visible) == [7, 8, 0, 1, 2])
        #expect(visible.last == 0)
    }
}

struct DrawerGeometryTests {
    @Test func theFrontDrawerFacesUsSquarely() {
        let front = DrawerGeometry(offset: 0, count: 7, drawerWidth: 248)
        #expect(front.x == 0)
        #expect(front.rotation == 0)
        #expect(front.depth == 0)
        #expect(front.scale == 1)
        #expect(front.opacity == 1)
        #expect(front.shade == 0)
    }

    @Test func neighboursTurnAwayRecedeAndDarken() {
        let right = DrawerGeometry(offset: 1, count: 7, drawerWidth: 248)
        let left = DrawerGeometry(offset: -1, count: 7, drawerWidth: 248)
        #expect(right.x > 0 && left.x < 0)
        #expect(abs(right.x + left.x) < 1e-9, "symmetric")
        // Eight faces at least: one step is 45°, the right-hand drawer turning its far edge away.
        #expect(abs(right.rotation + 45) < 1e-9)
        #expect(abs(left.rotation - 45) < 1e-9)
        #expect(right.depth < 0 && right.scale < 1)
        #expect(right.shade > 0)
        #expect(right.zIndex < DrawerGeometry(offset: 0, count: 7, drawerWidth: 248).zIndex)
    }

    @Test func drawersBehindTheDrumFadeOut() {
        let behind = DrawerGeometry(offset: 3, count: 8, drawerWidth: 248)
        #expect(behind.opacity == 0)
        #expect(!behind.isVisible)
        let edge = DrawerGeometry(offset: 1.8, count: 8, drawerWidth: 248)
        #expect(edge.opacity < 1 && edge.opacity > 0)
    }

    @Test func reduceMotionLaysTheDrawersFlat() {
        let right = DrawerGeometry(offset: 1, count: 7, drawerWidth: 248, reduceMotion: true)
        #expect(right.rotation == 0 && right.depth == 0 && right.shade == 0)
        #expect(right.x == 288)
        #expect(right.opacity == 0)
        let front = DrawerGeometry(offset: 0.2, count: 7, drawerWidth: 248, reduceMotion: true)
        #expect(front.opacity == 1)
    }
}

/// `TurningCabinet` is a View (main-actor isolated), so its statics are read on the main actor.
@MainActor
struct DrawerPullTests {
    @Test func pullingTowardYouRubberBandsLoosely() {
        let short = TurningCabinet.pullOffset(for: 20)
        #expect(short > 13 && short < 20, "close to 1:1 at first, got \(short)")
        // A long drag passes the opening threshold but never runs away.
        #expect(TurningCabinet.pullOffset(for: 280) > TurningCabinet.pullThreshold)
        #expect(TurningCabinet.pullOffset(for: 5000) < 320)
    }

    @Test func pushingAwayBarelyMoves() {
        let pushed = TurningCabinet.pullOffset(for: -200)
        #expect(pushed < 0 && pushed > -40)
    }

    @Test func aShortPullDoesntOpen() {
        #expect(TurningCabinet.pullOffset(for: 60) < TurningCabinet.pullThreshold)
    }
}

struct ChestMorphTests {
    @Test func pinchingInHeadsForTheChest() {
        #expect(ChestMorph.progress(magnification: 1, towardChest: true) == 0)
        #expect(abs(ChestMorph.progress(magnification: 0.75, towardChest: true) - 0.5) < 1e-9)
        #expect(ChestMorph.progress(magnification: 0.2, towardChest: true) == 1)
        // Opening the fingers on the cabinet doesn't move toward the chest.
        #expect(ChestMorph.progress(magnification: 1.4, towardChest: true) == 0)
    }

    @Test func pinchingOutHeadsBackToTheCabinet() {
        #expect(abs(ChestMorph.progress(magnification: 1.3, towardChest: false) - 0.5) < 1e-9)
        #expect(ChestMorph.progress(magnification: 2, towardChest: false) == 1)
        #expect(ChestMorph.progress(magnification: 0.8, towardChest: false) == 0)
    }

    @Test func onlyPastHalfwayCommits() {
        #expect(!ChestMorph.commits(0.5))
        #expect(ChestMorph.commits(0.51))
    }
}
