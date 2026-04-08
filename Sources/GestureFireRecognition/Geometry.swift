import Foundation
import simd

/// Cardinal directions in the normalized touchpad coordinate system (+y = up).
public enum Cardinal: Sendable, Equatable {
    case right
    case left
    case up
    case down
}

/// Small geometry helpers shared across recognizers.
/// Pure functions — no state, no timing. Used by direction-angle classification.
public enum Geometry {
    /// Classifies a 2D vector to its nearest cardinal direction and returns the
    /// angular offset (in degrees) from that cardinal axis.
    ///
    /// - Parameter vector: displacement in normalized coordinates.
    /// - Returns: `(cardinal, angleDegrees)` where `angleDegrees ∈ [0, 45]`,
    ///   or `nil` if `vector` is effectively the zero vector.
    ///
    /// Tiebreaking: when `|dx| == |dy|`, horizontal wins (`.right` or `.left`),
    /// which produces a deterministic result at exact 45° diagonals.
    public static func nearestCardinal(of vector: SIMD2<Float>) -> (cardinal: Cardinal, angleDegrees: Double)? {
        let magnitude = simd_length(vector)
        guard magnitude > 1e-6 else { return nil }

        let dx = Double(vector.x)
        let dy = Double(vector.y)
        let absDx = abs(dx)
        let absDy = abs(dy)

        if absDx >= absDy {
            // Horizontal dominant (or exact 45° tie → horizontal).
            let cardinal: Cardinal = dx >= 0 ? .right : .left
            let angle = atan2(absDy, absDx) * 180.0 / .pi
            return (cardinal, angle)
        } else {
            // Vertical dominant. +y is up in OMS.
            let cardinal: Cardinal = dy >= 0 ? .up : .down
            let angle = atan2(absDx, absDy) * 180.0 / .pi
            return (cardinal, angle)
        }
    }
}
