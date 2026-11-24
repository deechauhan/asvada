import Foundation

/// Where one drawer sits on the turning cabinet: pure maths from its offset to the front, so the
/// drum costs nothing to lay out and animates by interpolating the offset (ADR-0004).
///
/// The drawers sit on the faces of a ring seen from the front: each face is one step of
/// `2π / max(count, 8)` round, at a radius that makes neighbouring fronts just touch. Drawers
/// turning away rotate about the vertical axis, recede and darken; past about 78° they fade out.
/// Under Reduce Motion the ring is drawn flat: drawers slide side by side and crossfade.
struct DrawerGeometry: Equatable {
    /// Horizontal offset from the centre, in points.
    var x: Double
    /// Depth: 0 at the front, negative further away (used for scale and stacking).
    var depth: Double
    /// Rotation about the vertical axis, in degrees, in `rotation3DEffect`'s sense: drawers to the
    /// right turn negative, so their far edge recedes and their face looks back at the centre.
    var rotation: Double
    /// 0...1.
    var opacity: Double
    /// How dark the drawer's face is drawn, 0...0.62, as it turns away from the light.
    var shade: Double
    /// Stacking order: the front drawer is on top.
    var zIndex: Double

    /// The perspective SwiftUI's `rotation3DEffect` uses for the drum.
    static let perspective = 0.5
    /// How far the eye is from the front face, in points, for turning depth into scale.
    static let eyeDistance = 1100.0

    /// The geometry for a drawer `offset` drawers from the front, on a ring of `count` drawers,
    /// each `drawerWidth` points wide.
    init(offset: Double, count: Int, drawerWidth: Double, reduceMotion: Bool = false) {
        let distance = abs(offset)
        zIndex = 100 - distance * 10
        if reduceMotion {
            x = offset * (drawerWidth + 40)
            depth = 0
            rotation = 0
            opacity = distance < 0.5 ? 1 : max(0, 1 - (distance - 0.5) * 2.5)
            shade = 0
            return
        }
        let step = 2 * Double.pi / Double(max(count, 8))
        let radius = (drawerWidth / 2 + 8) / tan(step / 2)
        let angle = offset * step
        let facing = cos(angle)
        x = radius * sin(angle)
        depth = radius * (facing - 1)
        rotation = -angle * 180 / .pi
        opacity = facing > 0.2 ? 1 : max(0, facing / 0.2)
        shade = min(max((1 - facing) * 0.62, 0), 0.62)
    }

    /// The scale that stands in for depth (perspective on the z axis).
    var scale: Double {
        Self.eyeDistance / (Self.eyeDistance - depth)
    }

    /// Whether the drawer is worth drawing at all.
    var isVisible: Bool {
        opacity > 0.01
    }
}
