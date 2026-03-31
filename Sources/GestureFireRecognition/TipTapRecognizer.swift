import Foundation
import GestureFireTypes

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

        case .tracking(var fingers, var liftedFingers):
            // Clean up old lifted fingers (>1s)
            liftedFingers.removeAll { now.timeIntervalSince($0.liftTime) > 1.0 }

            let currentIDs = Set(frame.points.map(\.id))

            // Detect newly lifted fingers
            for (id, finger) in fingers where !currentIDs.contains(id) {
                if finger.duration < tapMaxSec && finger.isStationary(tolerance: tolerance) {
                    liftedFingers.append(LiftedFinger(finger: finger, liftTime: now))
                }
            }

            // Update existing fingers and add new ones
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

            // Find hold fingers: stationary + held long enough
            let holdFingers = updatedFingers.values.filter { finger in
                finger.isStationary(tolerance: tolerance) && finger.duration >= holdThresholdSec
            }

            // Try to match a lifted finger with a hold finger
            if let holdFinger = holdFingers.first {
                for (index, lifted) in liftedFingers.enumerated().reversed() {
                    guard lifted.finger.id != holdFinger.id else { continue }
                    guard now.timeIntervalSince(lifted.liftTime) < 0.5 else { continue }

                    // Success — compute direction
                    let gesture = computeDirection(
                        holdPos: holdFinger.startPosition,
                        tapPos: lifted.finger.startPosition
                    )

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
                // Re-process this frame in idle state
                return processFrame(frame)
            }
            return .empty
        }
    }

    // MARK: - Direction computation

    private func computeDirection(holdPos: SIMD2<Float>, tapPos: SIMD2<Float>) -> GestureType {
        let dx = tapPos.x - holdPos.x
        let dy = tapPos.y - holdPos.y

        if abs(dx) > abs(dy) {
            return dx > 0 ? .tipTapRight : .tipTapLeft
        } else {
            // Positive Y = up in trackpad coordinates
            return dy > 0 ? .tipTapUp : .tipTapDown
        }
    }
}
