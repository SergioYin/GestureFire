import Foundation
import GestureFireTypes

/// Test fixture factory for touch frames.
enum Fixtures {
    static let baseTime = Date(timeIntervalSinceReferenceDate: 0)

    /// Create a TouchPoint at a given position.
    static func point(
        id: Int32,
        x: Float, y: Float,
        state: TouchState = .touching,
        at time: Date = baseTime
    ) -> TouchPoint {
        TouchPoint(id: id, position: SIMD2(x, y), state: state, timestamp: time)
    }

    /// Create a TouchFrame with given points.
    static func frame(_ points: [TouchPoint], at time: Date) -> TouchFrame {
        TouchFrame(points: points, timestamp: time)
    }

    /// Time offset from base in seconds.
    static func time(_ offsetMs: Int) -> Date {
        baseTime.addingTimeInterval(TimeInterval(offsetMs) / 1000.0)
    }

    /// Generate a typical TipTap frame sequence:
    /// 1. Hold finger appears (frames 0-N)
    /// 2. Tap finger appears briefly alongside hold finger
    /// 3. Tap finger disappears while hold finger remains
    ///
    /// Returns frames that should produce a TipTap recognition.
    static func tipTapSequence(
        holdPos: SIMD2<Float> = SIMD2(0.3, 0.5),
        tapPos: SIMD2<Float> = SIMD2(0.7, 0.5),
        holdStartMs: Int = 0,
        tapAppearMs: Int = 250,
        tapDisappearMs: Int = 350,
        postTapMs: Int = 400,
        frameIntervalMs: Int = 16
    ) -> [TouchFrame] {
        var frames: [TouchFrame] = []
        let holdId: Int32 = 1
        let tapId: Int32 = 2

        // Phase 1: Hold finger only (establishing hold)
        var t = holdStartMs
        while t < tapAppearMs {
            frames.append(frame([
                point(id: holdId, x: holdPos.x, y: holdPos.y, at: time(t)),
            ], at: time(t)))
            t += frameIntervalMs
        }

        // Phase 2: Both fingers (tap finger appears)
        t = tapAppearMs
        while t < tapDisappearMs {
            frames.append(frame([
                point(id: holdId, x: holdPos.x, y: holdPos.y, at: time(t)),
                point(id: tapId, x: tapPos.x, y: tapPos.y, at: time(t)),
            ], at: time(t)))
            t += frameIntervalMs
        }

        // Phase 3: Hold finger only again (tap finger lifted)
        t = tapDisappearMs
        while t <= postTapMs {
            frames.append(frame([
                point(id: holdId, x: holdPos.x, y: holdPos.y, at: time(t)),
            ], at: time(t)))
            t += frameIntervalMs
        }

        return frames
    }

    /// Generate a multi-finger tap frame sequence:
    /// 1. All N fingers touch down at `touchdownMs` (all within the same frame)
    /// 2. Fingers stay stationary until `liftMs`
    /// 3. Post-lift empty frames so the recognizer observes the lift
    ///
    /// `positions.count` determines the finger count. Each entry is the
    /// stationary position for that finger over the whole sequence.
    static func multiFingerTapSequence(
        positions: [SIMD2<Float>],
        touchdownMs: Int = 0,
        liftMs: Int = 120,
        postLiftMs: Int = 200,
        frameIntervalMs: Int = 16
    ) -> [TouchFrame] {
        precondition(positions.count >= 2, "Need at least 2 fingers")
        var frames: [TouchFrame] = []

        // Phase 1: empty pre-roll (none by default)
        var t = 0
        while t < touchdownMs {
            frames.append(frame([], at: time(t)))
            t += frameIntervalMs
        }

        // Phase 2: all N fingers present and stationary
        t = touchdownMs
        while t <= liftMs {
            let pts = positions.enumerated().map { idx, pos in
                point(id: Int32(idx + 1), x: pos.x, y: pos.y, at: time(t))
            }
            frames.append(frame(pts, at: time(t)))
            t += frameIntervalMs
        }

        // Phase 3: post-lift empty frames
        t = liftMs + frameIntervalMs
        let postEnd = liftMs + postLiftMs
        while t <= postEnd {
            frames.append(frame([], at: time(t)))
            t += frameIntervalMs
        }

        return frames
    }

    /// Convenience: N fingers clustered around a centroid with small offsets.
    /// Produces positions that fit comfortably within the default
    /// `fingerProximityThreshold × 3` spread for multi-finger taps.
    static func multiFingerCluster(count: Int, centroid: SIMD2<Float> = SIMD2(0.5, 0.5), spacing: Float = 0.05) -> [SIMD2<Float>] {
        precondition(count >= 2 && count <= 5)
        // Small horizontal fan centred on `centroid`.
        let offsets: [Float] = {
            switch count {
            case 2: return [-0.5, 0.5]
            case 3: return [-1.0, 0.0, 1.0]
            case 4: return [-1.5, -0.5, 0.5, 1.5]
            case 5: return [-2.0, -1.0, 0.0, 1.0, 2.0]
            default: return []
            }
        }()
        return offsets.map { SIMD2(centroid.x + $0 * spacing, centroid.y) }
    }

    /// Generate a single-finger corner tap frame sequence:
    /// 1. One finger appears at `position` (frames 0..tapDurationMs)
    /// 2. Finger disappears (post-lift frames)
    ///
    /// Returns frames that should produce a CornerTap recognition when
    /// `position` falls inside a corner region.
    static func cornerTapSequence(
        position: SIMD2<Float>,
        tapStartMs: Int = 0,
        tapDurationMs: Int = 120,
        postLiftMs: Int = 200,
        frameIntervalMs: Int = 16
    ) -> [TouchFrame] {
        var frames: [TouchFrame] = []
        let fingerId: Int32 = 1

        var t = tapStartMs
        let tapEnd = tapStartMs + tapDurationMs
        while t <= tapEnd {
            frames.append(frame([
                point(id: fingerId, x: position.x, y: position.y, at: time(t)),
            ], at: time(t)))
            t += frameIntervalMs
        }

        // Post-lift: empty frames so the recognizer observes the lift.
        t = tapEnd + frameIntervalMs
        let postEnd = tapEnd + postLiftMs
        while t <= postEnd {
            frames.append(frame([], at: time(t)))
            t += frameIntervalMs
        }

        return frames
    }
}
