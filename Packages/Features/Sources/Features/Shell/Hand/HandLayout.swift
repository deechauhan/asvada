import CoreGraphics
import Foundation

/// The hand of blank keepsakes that fans out over the savour pill (INTERACTION.md §5): where each
/// blank sits on its arc, and which one the thumb is on.
///
/// Blanks keep cabinet order, left to right, at fixed angles, so the same slide (or a quick
/// flick before the hand has even appeared) always draws the same blank. Angles are measured
/// from straight up, clockwise, in degrees.
struct HandLayout: Equatable {
    /// How many blanks are in the hand (at most `maximumCount`).
    let count: Int

    /// The most blanks a hand holds; later collections are reached from the sheet.
    static let maximumCount = 8
    /// The distance from the pill's centre to each blank's centre, in points.
    static let radius: CGFloat = 150
    /// No blank is chosen while the thumb is this close to the pill.
    static let deadZone: CGFloat = 46
    /// Sliding this far below the pill cancels the draw.
    static let cancelDepth: CGFloat = 12
    /// The angle between neighbouring blanks, and the widest the arc may open.
    static let step = 22.0
    static let maximumSpread = 150.0

    init(count: Int) {
        self.count = min(max(count, 0), Self.maximumCount)
    }

    /// The angle between neighbouring blanks for this hand.
    var spacing: Double {
        guard count > 1 else { return 0 }
        return min(Self.step, Self.maximumSpread / Double(count - 1))
    }

    /// The angle of blank `index`, from straight up (negative to the left).
    func angle(of index: Int) -> Double {
        (Double(index) - Double(count - 1) / 2) * spacing
    }

    /// Where blank `index` sits relative to the pill's centre (y grows downward, as in SwiftUI).
    func position(of index: Int) -> CGPoint {
        let radians = angle(of: index) * .pi / 180
        return CGPoint(x: Self.radius * sin(radians), y: -Self.radius * cos(radians))
    }

    /// The blank the thumb is on, for a thumb `offset` from where it pressed the pill, or `nil`
    /// inside the dead zone or below the pill (which cancels).
    func selection(for offset: CGSize) -> Int? {
        let reach = hypot(offset.width, offset.height)
        guard count >= 1, offset.height < Self.cancelDepth, reach >= Self.deadZone else { return nil }
        let angle = atan2(Double(offset.width), Double(-offset.height)) * 180 / .pi
        guard count > 1 else { return 0 }
        let index = (angle / spacing + Double(count - 1) / 2).rounded()
        return Int(min(max(index, 0), Double(count - 1)))
    }
}
