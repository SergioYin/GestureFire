import Foundation
import GestureFireTypes
import simd

/// Recognizes a simultaneous multi-finger tap with 3, 4, or 5 fingers.
///
/// Rules:
/// - All fingers must touch down within `tapGroupingWindowMs` of the first
///   touchdown. Any finger that arrives later aborts the gesture.
/// - Every tracked finger must stay stationary within `movementTolerance`.
/// - Total time from the first touchdown to all fingers lifting must not
///   exceed `tapMaxDurationMs`.
/// - Pairwise max distance between finger start positions must not exceed
///   `fingerProximityThreshold × 3` (the "max spread" for a single cluster).
/// - Peak finger count must be exactly 3, 4, or 5; 2 fingers is TipTap
///   territory and is ignored silently.
///
/// Priority: placed between `CornerTapRecognizer` and `TipTapRecognizer` in
/// `RecognitionLoop`. Cannot collide with TipTap because TipTap uses exactly
/// 1 hold + 1 tap (peak count 2).
///
/// Timestamp authority: all timing uses `TouchFrame.timestamp` — no `Date()`.
public struct MultiFingerTapRecognizer: GestureRecognizer {
    public enum State: Sendable, Equatable {
        case idle
        /// Accumulating touchdowns within the grouping window.
        case grouping(fingers: [Int32: TrackedFinger], firstTouchdownTime: Date, peakCount: Int)
        case cooldown(until: Date)
    }

    private(set) public var state: State = .idle
    private let sensitivity: SensitivityConfig

    public init(sensitivity: SensitivityConfig) {
        self.sensitivity = sensitivity
    }

    // MARK: - State inspection for tests

    public var isIdle: Bool { if case .idle = state { return true }; return false }
    public var isGrouping: Bool { if case .grouping = state { return true }; return false }
    public var isCooldown: Bool { if case .cooldown = state { return true }; return false }

    // MARK: - Process frame

    public mutating func processFrame(_ frame: TouchFrame) -> RecognitionResult {
        let now = frame.timestamp
        let tolerance = Float(sensitivity.multiFingerMovementTolerance)
        let tapMaxSec = sensitivity.multiFingerTapDurationMs / 1000.0
        let cooldownSec = sensitivity.debounceCooldownMs / 1000.0
        let groupingWindowSec = sensitivity.tapGroupingWindowMs / 1000.0
        let maxSpread = Float(sensitivity.multiFingerSpreadMax)

        // Include .breaking so staggered lifts don't cause premature finger-count
        // drops on real hardware where fingers transition through breaking → leaving
        // over 1-2 frames.
        let active = frame.points.filter {
            $0.state == .touching || $0.state == .making || $0.state == .breaking
        }
        // For grouping entry, only use firmly-down fingers (not breaking).
        let firmlyDown = frame.points.filter { $0.state == .touching || $0.state == .making }

        switch state {
        case .idle:
            if firmlyDown.isEmpty { return .empty }
            var fingers: [Int32: TrackedFinger] = [:]
            for p in firmlyDown {
                fingers[p.id] = TrackedFinger(id: p.id, position: p.position, time: now)
            }
            if let spread = maxPairwiseDistance(fingers: fingers), spread > maxSpread {
                state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                return .rejected([RejectionReason(
                    recognizer: "MultiFingerTap",
                    parameter: "multiFingerSpreadMax",
                    threshold: Double(maxSpread),
                    actual: Double(spread),
                    label: "fingersTooSpread"
                )])
            }
            state = .grouping(
                fingers: fingers,
                firstTouchdownTime: now,
                peakCount: fingers.count
            )
            return .empty

        case .grouping(var fingers, let firstTouchdown, var peakCount):
            // Build updated fingers set using `active` (includes .breaking) so
            // staggered lifts don't cause premature "all lifted" evaluation.
            // New finger detection uses `firmlyDown` only — a finger in .breaking
            // should not be treated as a new arrival.
            var updated: [Int32: TrackedFinger] = [:]
            for p in active {
                if var existing = fingers[p.id] {
                    existing.lastPosition = p.position
                    existing.lastTime = now
                    updated[p.id] = existing
                } else if p.state == .touching || p.state == .making {
                    // New finger (firmly down, not breaking)
                    if now.timeIntervalSince(firstTouchdown) > groupingWindowSec {
                        state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                        return .empty
                    }
                    updated[p.id] = TrackedFinger(id: p.id, position: p.position, time: now)
                }
            }

            // Movement check
            for (_, finger) in updated where !finger.isStationary(tolerance: tolerance) {
                state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                return .rejected([RejectionReason(
                    recognizer: "MultiFingerTap",
                    parameter: "multiFingerMovementTolerance",
                    threshold: sensitivity.multiFingerMovementTolerance,
                    actual: Double(finger.displacement),
                    label: "fingerMoved"
                )])
            }

            // Spread check on tracked start positions
            if let spread = maxPairwiseDistance(fingers: updated), spread > maxSpread {
                state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                return .rejected([RejectionReason(
                    recognizer: "MultiFingerTap",
                    parameter: "multiFingerSpreadMax",
                    threshold: Double(maxSpread),
                    actual: Double(spread),
                    label: "fingersTooSpread"
                )])
            }

            peakCount = max(peakCount, updated.count)

            // Tap-too-slow: still holding past max tap duration
            if !updated.isEmpty && now.timeIntervalSince(firstTouchdown) > tapMaxSec {
                state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                return .rejected([RejectionReason(
                    recognizer: "MultiFingerTap",
                    parameter: "multiFingerTapDurationMs",
                    threshold: sensitivity.multiFingerTapDurationMs,
                    actual: now.timeIntervalSince(firstTouchdown) * 1000.0,
                    label: "tapTooSlow"
                )])
            }

            // All fingers lifted → evaluate final result
            if updated.isEmpty {
                let totalDuration = now.timeIntervalSince(firstTouchdown)
                if totalDuration <= tapMaxSec, let gesture = Self.gestureType(for: peakCount) {
                    state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                    return .recognized(gesture)
                } else {
                    // Peak count not in {3,4,5} — not my gesture. Quiet reset.
                    state = .idle
                    return .empty
                }
            }

            state = .grouping(
                fingers: updated,
                firstTouchdownTime: firstTouchdown,
                peakCount: peakCount
            )
            return .empty

        case .cooldown(let until):
            if now < until { return .empty }
            // Inline idle re-entry — use firmlyDown (not breaking) for new grouping.
            state = .idle
            if firmlyDown.isEmpty { return .empty }
            var fingers: [Int32: TrackedFinger] = [:]
            for p in firmlyDown {
                fingers[p.id] = TrackedFinger(id: p.id, position: p.position, time: now)
            }
            if let spread = maxPairwiseDistance(fingers: fingers), spread > maxSpread {
                state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                return .empty
            }
            state = .grouping(
                fingers: fingers,
                firstTouchdownTime: now,
                peakCount: fingers.count
            )
            return .empty
        }
    }

    // MARK: - Helpers

    /// Max pairwise distance between any two tracked finger start positions,
    /// or `nil` if fewer than 2 fingers are tracked.
    private func maxPairwiseDistance(fingers: [Int32: TrackedFinger]) -> Float? {
        let positions = fingers.values.map { $0.startPosition }
        guard positions.count >= 2 else { return nil }
        var maxDist: Float = 0
        for i in 0..<positions.count {
            for j in (i + 1)..<positions.count {
                let d = simd_distance(positions[i], positions[j])
                if d > maxDist { maxDist = d }
            }
        }
        return maxDist
    }

    private static func gestureType(for count: Int) -> GestureType? {
        switch count {
        case 3: return .multiFingerTap3
        case 4: return .multiFingerTap4
        case 5: return .multiFingerTap5
        default: return nil
        }
    }
}
