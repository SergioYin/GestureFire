import Foundation
import GestureFireTypes
import simd

/// Recognizes TipTap gestures (hold one finger, tap another in a direction).
/// Struct with explicit state machine. Owned exclusively by RecognitionLoop actor.
/// All timing uses TouchFrame.timestamp — no Date() calls.
public struct TipTapRecognizer: GestureRecognizer {
    public enum State: Sendable, Equatable {
        case idle
        /// Tracking active fingers. holdFingers: stationary fingers held long enough.
        case tracking(fingers: [Int32: TrackedFinger], liftedFingers: [LiftedFinger])
        /// After successful recognition, wait for cooldown.
        case cooldown(until: Date)
    }

    private(set) public var state: State = .idle
    private let sensitivity: SensitivityConfig

    public init(sensitivity: SensitivityConfig) {
        self.sensitivity = sensitivity
    }

    // MARK: - State inspection for tests

    public var isIdle: Bool {
        if case .idle = state { return true }
        return false
    }

    public var isTracking: Bool {
        if case .tracking = state { return true }
        return false
    }

    public var isCooldown: Bool {
        if case .cooldown = state { return true }
        return false
    }

    // MARK: - Process frame

    public mutating func processFrame(_ frame: TouchFrame) -> RecognitionResult {
        let now = frame.timestamp
        let tolerance = Float(sensitivity.movementTolerance)
        let holdThresholdSec = sensitivity.holdThresholdMs / 1000.0
        let tapMaxSec = sensitivity.tapMaxDurationMs / 1000.0
        let cooldownSec = sensitivity.debounceCooldownMs / 1000.0
        let tapGroupingWindowSec = sensitivity.tapGroupingWindowMs / 1000.0
        let liftedFingerEvictionSec = tapGroupingWindowSec * 2 // keep lifted fingers for 2× grouping window

        switch state {
        case .idle:
            if frame.points.isEmpty { return .empty }
            // Start tracking
            var fingers: [Int32: TrackedFinger] = [:]
            for p in frame.points where p.state == .touching || p.state == .making {
                fingers[p.id] = TrackedFinger(id: p.id, position: p.position, time: now)
            }
            if !fingers.isEmpty {
                state = .tracking(fingers: fingers, liftedFingers: [])
            }
            return .empty

        case .tracking(let fingers, var liftedFingers):
            // Clean up old lifted fingers (eviction = 2× tap grouping window)
            liftedFingers.removeAll { now.timeIntervalSince($0.liftTime) > liftedFingerEvictionSec }

            // Build current active fingers (touching/making only) FIRST
            var updatedFingers: [Int32: TrackedFinger] = [:]
            for p in frame.points where p.state == .touching || p.state == .making {
                if var existing = fingers[p.id] {
                    existing.lastPosition = p.position
                    existing.lastTime = now
                    updatedFingers[p.id] = existing
                } else {
                    updatedFingers[p.id] = TrackedFinger(id: p.id, position: p.position, time: now)
                }
            }

            // Detect lifted fingers: was tracked but no longer in active state.
            // This catches fingers transitioning to .breaking/.leaving immediately,
            // rather than waiting for the ID to fully disappear from the frame.
            for (id, finger) in fingers where updatedFingers[id] == nil {
                if finger.duration < tapMaxSec && finger.isStationary(tolerance: tolerance) {
                    liftedFingers.append(LiftedFinger(finger: finger, liftTime: now))
                }
            }

            // Find hold fingers: stationary + held long enough
            let holdFingers = updatedFingers.values.filter { finger in
                finger.isStationary(tolerance: tolerance) && finger.duration >= holdThresholdSec
            }

            // Try to match a lifted finger with a hold finger
            let proximityThreshold = Float(sensitivity.fingerProximityThreshold)

            if let holdFinger = holdFingers.first {
                for lifted in liftedFingers.reversed() {
                    guard lifted.finger.id != holdFinger.id else { continue }
                    guard now.timeIntervalSince(lifted.liftTime) < tapGroupingWindowSec else { continue }
                    // Reject two-finger swipes: hold and tap must be far enough apart
                    guard simd_distance(holdFinger.startPosition, lifted.finger.startPosition) >= proximityThreshold else { continue }

                    // Direction classification with angle-tolerance gate
                    let vector = lifted.finger.startPosition - holdFinger.startPosition
                    guard let classification = Geometry.nearestCardinal(of: vector) else {
                        // Zero displacement — treat as ambiguous and reject.
                        state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                        return .rejected([RejectionReason(
                            recognizer: "TipTap",
                            parameter: "directionAngleTolerance",
                            threshold: sensitivity.directionAngleTolerance,
                            actual: 90.0,
                            label: "directionAmbiguous"
                        )])
                    }

                    if classification.angleDegrees > sensitivity.directionAngleTolerance {
                        state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                        return .rejected([RejectionReason(
                            recognizer: "TipTap",
                            parameter: "directionAngleTolerance",
                            threshold: sensitivity.directionAngleTolerance,
                            actual: classification.angleDegrees,
                            label: "directionAmbiguous"
                        )])
                    }

                    let gesture = gestureType(for: classification.cardinal)
                    state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                    return .recognized(gesture)
                }
            }

            // No match yet — keep tracking
            if updatedFingers.isEmpty && liftedFingers.isEmpty {
                state = .idle
            } else {
                state = .tracking(fingers: updatedFingers, liftedFingers: liftedFingers)
            }
            return .empty

        case .cooldown(let until):
            if now >= until {
                state = .idle
                // Inline idle-state logic to avoid recursive mutating re-entry
                if frame.points.isEmpty { return .empty }
                var fingers: [Int32: TrackedFinger] = [:]
                for p in frame.points where p.state == .touching || p.state == .making {
                    fingers[p.id] = TrackedFinger(id: p.id, position: p.position, time: now)
                }
                if !fingers.isEmpty {
                    state = .tracking(fingers: fingers, liftedFingers: [])
                }
                return .empty
            }
            return .empty
        }
    }

    // MARK: - Direction computation

    private func gestureType(for cardinal: Cardinal) -> GestureType {
        switch cardinal {
        case .right: return .tipTapRight
        case .left:  return .tipTapLeft
        case .up:    return .tipTapUp
        case .down:  return .tipTapDown
        }
    }
}
