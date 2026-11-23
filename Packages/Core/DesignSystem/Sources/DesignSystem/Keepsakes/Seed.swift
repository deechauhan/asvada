/// Stable, deterministic numbers derived from an id (unlike `hashValue`, which changes on every
/// launch), so a keepsake keeps the same tilt and stamp shape forever.
public enum Seed {
    /// 64-bit FNV-1a hash of the UTF-8 bytes.
    public static func hash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// A value in `-1...1` derived from the id.
    public static func unit(_ string: String) -> Double {
        Double(hash(string) % 20001) / 10000 - 1
    }
}

/// How much things lean, so pages look placed by hand rather than laid out in rows.
public enum Tilt {
    /// Keepsakes lean up to ±2°.
    public static let keepsakeMax = 2.0
    /// Stamps lean up to ±8°.
    public static let stampMax = 8.0

    /// A deterministic angle in degrees for `id`, within `±max`.
    public static func degrees(for id: String, max: Double = keepsakeMax) -> Double {
        (Seed.unit(id) * max * 10).rounded() / 10
    }
}
