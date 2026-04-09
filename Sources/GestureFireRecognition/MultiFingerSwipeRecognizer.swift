import Foundation
import GestureFireTypes
import simd

/// Recognizes a multi-finger directional swipe with 3 or 4 fingers.
///
/// Rules:
/// - All fingers must touch down within `tapGroupingWindowMs` of the first
///   touchdown. Late arrivals abort the gesture (cooldown).
/// - Throughout the motion, every tracked finger must remain within
///   `fingerProximityThreshold` of the *current* centroid (the cluster
///   stays together — diverging fingers reject as `clusterBroken`).
/// - The centroid must travel at least `swipeMinDistance` between the
///   first frame and lift; otherwise it is "not my gesture" and the
///   recognizer resets silently (so 3-finger taps stay with the tap
///   recognizer instead of producing noisy swipe rejections).
/// - The vector from the initial centroid to the final centroid must
///   be within `directionAngleTolerance` of a cardinal axis. Otherwise
///   it is rejected as `directionAmbiguous` (same label as TipTap).
/// - Total duration from first touchdown to final lift must not exceed
///   `swipeMaxDurationMs`; otherwise rejected as `swipeTooSlow`.
/// - Peak finger count must be exactly 3 or 4. Counts of 2 or 5 are
///   silently ignored — TipTap and a hypothetical 5-finger handler own
///   those.
///
/// Priority: position 3 in `RecognitionLoop`, between MultiFingerTap
/// and TipTap. MultiFingerTap fires first for clean stationary taps;
/// MultiFingerSwipe only fires once the cluster actually translates.
///
/// Timestamp authority: all timing uses `TouchFrame.timestamp`.
public struct MultiFingerSwipeRecognizer: GestureRecognizer {
    public enum State: Sendable, Equatable {
        case idle
        /// Cluster is being tracked. Fingers may still be arriving (until
        /// the grouping window closes), and motion may or may not have
        /// started. Recognition happens on the lift frame.
        case tracking(
            fingers: [Int32: TrackedFinger],
            firstTouchdownTime: Date,
            initialCentroid: SIMD2<Float>,
            peakCount: Int
        )
        case cooldown(until: Date)
    }

    private(set) public var state: State = .idle
    private let sensitivity: SensitivityConfig

    public init(sensitivity: SensitivityConfig) {
        self.sensitivity = sensitivity
    }

    // MARK: - State inspection

    public var isIdle: Bool { if case .idle = state { return true }; return false }
    public var isTracking: Bool { if case .tracking = state { return true }; return false }
    public var isCooldown: Bool { if case .cooldown = state { return true }; return false }

    // MARK: - Process frame

    public mutating func processFrame(_ frame: TouchFrame) -> RecognitionResult {
        let now = frame.timestamp
        let proximityThreshold = Float(sensitivity.fingerProximityThreshold)
        let swipeMinDistance = Float(sensitivity.swipeMinDistance)
        let swipeMaxSec = sensitivity.swipeMaxDurationMs / 1000.0
        let cooldownSec = sensitivity.debounceCooldownMs / 1000.0
        let groupingWindowSec = sensitivity.tapGroupingWindowMs / 1000.0
        let angleTolerance = sensitivity.directionAngleTolerance

        let active = frame.points.filter { $0.state == .touching || $0.state == .making }

        switch state {
        case .idle:
            if active.isEmpty { return .empty }
            var fingers: [Int32: TrackedFinger] = [:]
            for p in active {
                fingers[p.id] = TrackedFinger(id: p.id, position: p.position, time: now)
            }
            let centroid = Self.centroid(of: fingers.values.map { $0.startPosition })
            state = .tracking(
                fingers: fingers,
                firstTouchdownTime: now,
                initialCentroid: centroid,
                peakCount: fingers.count
            )
            return .empty

        case .tracking(var fingers, let firstTouchdown, var initialCentroid, var peakCount):
            // Build updated fingers; reject late arrivals.
            var updated: [Int32: TrackedFinger] = [:]
            var newFingerArrived = false
            for p in active {
                if var existing = fingers[p.id] {
                    existing.lastPosition = p.position
                    existing.lastTime = now
                    updated[p.id] = existing
                } else {
                    if now.timeIntervalSince(firstTouchdown) > groupingWindowSec {
                        // Late touchdown — abort to cooldown silently so the
                        // ongoing touch cannot re-enter tracking after lift.
                        state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                        return .empty
                    }
                    updated[p.id] = TrackedFinger(id: p.id, position: p.position, time: now)
                    newFingerArrived = true
                }
            }

            // If a new finger joined inside the grouping window, recompute the
            // initial centroid so it includes ALL fingers' start positions.
            // This is what makes "grouping + motion" coexist cleanly: the
            // initial centroid is the centroid of all fingers' touchdown
            // positions, regardless of when each one arrived.
            if newFingerArrived {
                initialCentroid = Self.centroid(of: updated.values.map { $0.startPosition })
            }

            peakCount = max(peakCount, updated.count)

            // Per-frame cluster integrity check using current finger positions.
            if !updated.isEmpty {
                let currentCentroid = Self.centroid(of: updated.values.map { $0.lastPosition })
                if let outlier = Self.maxDistance(from: currentCentroid, in: updated.values.map { $0.lastPosition }),
                   outlier > proximityThreshold {
                    state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                    return .rejected([RejectionReason(
                        recognizer: "MultiFingerSwipe",
                        parameter: "fingerProximityThreshold",
                        threshold: sensitivity.fingerProximityThreshold,
                        actual: Double(outlier),
                        label: "clusterBroken"
                    )])
                }
            }

            // Swipe-too-slow: still touching past max duration.
            if !updated.isEmpty && now.timeIntervalSince(firstTouchdown) > swipeMaxSec {
                state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                return .rejected([RejectionReason(
                    recognizer: "MultiFingerSwipe",
                    parameter: "swipeMaxDurationMs",
                    threshold: sensitivity.swipeMaxDurationMs,
                    actual: now.timeIntervalSince(firstTouchdown) * 1000.0,
                    label: "swipeTooSlow"
                )])
            }

            // All fingers lifted → evaluate the swipe.
            if updated.isEmpty {
                // Use the LAST known positions of every tracked finger to
                // compute the final centroid (lift frame has empty `active`,
                // so we rely on the cached lastPosition from the previous
                // frame for each tracked finger).
                let lastPositions = fingers.values.map { $0.lastPosition }
                let finalCentroid = Self.centroid(of: lastPositions)
                let displacement = simd_distance(initialCentroid, finalCentroid)
                let totalDuration = now.timeIntervalSince(firstTouchdown)

                // Wrong finger count — quietly hand back to other recognizers.
                guard peakCount == 3 || peakCount == 4 else {
                    state = .idle
                    return .empty
                }

                // Below motion threshold → not our gesture, no rejection noise.
                if displacement < swipeMinDistance {
                    state = .idle
                    return .empty
                }

                // Duration cap (final guard — also enforced per-frame above).
                if totalDuration > swipeMaxSec {
                    state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                    return .rejected([RejectionReason(
                        recognizer: "MultiFingerSwipe",
                        parameter: "swipeMaxDurationMs",
                        threshold: sensitivity.swipeMaxDurationMs,
                        actual: totalDuration * 1000.0,
                        label: "swipeTooSlow"
                    )])
                }

                // Direction classification via shared Geometry.
                let vector = finalCentroid - initialCentroid
                guard let (cardinal, angle) = Geometry.nearestCardinal(of: vector) else {
                    state = .idle
                    return .empty
                }
                if angle > angleTolerance {
                    state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                    return .rejected([RejectionReason(
                        recognizer: "MultiFingerSwipe",
                        parameter: "directionAngleTolerance",
                        threshold: angleTolerance,
                        actual: angle,
                        label: "directionAmbiguous"
                    )])
                }

                let gesture = Self.gestureType(count: peakCount, cardinal: cardinal)
                state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                return .recognized(gesture)
            }

            state = .tracking(
                fingers: updated,
                firstTouchdownTime: firstTouchdown,
                initialCentroid: initialCentroid,
                peakCount: peakCount
            )
            return .empty

        case .cooldown(let until):
            if now < until { return .empty }
            // Inline idle re-entry — avoid recursive mutating call.
            state = .idle
            if active.isEmpty { return .empty }
            var fingers: [Int32: TrackedFinger] = [:]
            for p in active {
                fingers[p.id] = TrackedFinger(id: p.id, position: p.position, time: now)
            }
            let centroid = Self.centroid(of: fingers.values.map { $0.startPosition })
            state = .tracking(
                fingers: fingers,
                firstTouchdownTime: now,
                initialCentroid: centroid,
                peakCount: fingers.count
            )
            return .empty
        }
    }

    // MARK: - Helpers

    private static func centroid(of positions: [SIMD2<Float>]) -> SIMD2<Float> {
        guard !positions.isEmpty else { return SIMD2(0, 0) }
        var sum = SIMD2<Float>(0, 0)
        for p in positions { sum += p }
        return sum / Float(positions.count)
    }

    /// Largest distance from `point` to any element of `positions`,
    /// or `nil` if `positions` is empty.
    private static func maxDistance(from point: SIMD2<Float>, in positions: [SIMD2<Float>]) -> Float? {
        guard !positions.isEmpty else { return nil }
        var maxD: Float = 0
        for p in positions {
            let d = simd_distance(point, p)
            if d > maxD { maxD = d }
        }
        return maxD
    }

    private static func gestureType(count: Int, cardinal: Cardinal) -> GestureType {
        switch (count, cardinal) {
        case (3, .right): return .multiFingerSwipe3Right
        case (3, .left): return .multiFingerSwipe3Left
        case (3, .up): return .multiFingerSwipe3Up
        case (3, .down): return .multiFingerSwipe3Down
        case (4, .right): return .multiFingerSwipe4Right
        case (4, .left): return .multiFingerSwipe4Left
        case (4, .up): return .multiFingerSwipe4Up
        case (4, .down): return .multiFingerSwipe4Down
        default:
            // Unreachable — peakCount guard above ensures count ∈ {3,4}.
            return .multiFingerSwipe3Right
        }
    }
}
