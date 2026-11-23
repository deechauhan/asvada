import Foundation

/// The Robinson projection: the gently curved world most atlases use. Unlike equirectangular it
/// doesn't balloon the poles, so Europe and Africa keep believable sizes.
///
/// Implemented from Robinson's table (every 5° of latitude) with linear interpolation, which is
/// how the projection is defined. Output is in "map units": x in -1...1 at the equator's ends,
/// y in about -0.507...0.507 (north up, positive).
public enum Robinson {
    /// Parallel length (PLEN) and distance from the equator (PDFE) at 0°, 5° … 90°.
    static let table: [(plen: Double, pdfe: Double)] = [
        (1.0000, 0.0000),
        (0.9986, 0.0620),
        (0.9954, 0.1240),
        (0.9900, 0.1860),
        (0.9822, 0.2480),
        (0.9730, 0.3100),
        (0.9600, 0.3720),
        (0.9427, 0.4340),
        (0.9216, 0.4958),
        (0.8962, 0.5571),
        (0.8679, 0.6176),
        (0.8350, 0.6769),
        (0.7986, 0.7346),
        (0.7597, 0.7903),
        (0.7186, 0.8435),
        (0.6732, 0.8936),
        (0.6213, 0.9394),
        (0.5722, 0.9761),
        (0.5322, 1.0000),
    ]

    /// Height of the map relative to its width (y-range over x-range).
    public static let aspect = 0.5072

    /// Projects `point` to map units (x -1...1, y about -0.507...0.507, north positive).
    public static func project(_ point: GeoPoint) -> (x: Double, y: Double) {
        let latitude = min(max(point.latitude, -90), 90)
        let longitude = min(max(point.longitude, -180), 180)
        let index = min(Int(abs(latitude) / 5), table.count - 2)
        let fraction = (abs(latitude) - Double(index) * 5) / 5
        let plen = table[index].plen + (table[index + 1].plen - table[index].plen) * fraction
        let pdfe = table[index].pdfe + (table[index + 1].pdfe - table[index].pdfe) * fraction
        let x = plen * longitude / 180
        let y = pdfe * aspect * (latitude < 0 ? -1 : 1)
        return (x, y)
    }
}
