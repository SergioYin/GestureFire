import Foundation
import GestureFireTypes
import simd

/// Recognizes a single-finger tap inside one of the four corner regions.
///
/// Priority (highest-first) in `RecognitionLoop`: CornerTap runs before TipTap so
/// that a tap in a corner region is never accidentally swallowed by the tap-only
/// half of TipTap's state machine.
///
/// All timing uses `TouchFrame.timestamp` — no `Date()` calls.
public struct CornerTapRecognizer: GestureRecognizer {
    public enum Corner: Sendable, Equatable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    public enum State: Sendable, Equatable {
        case idle
        /// Tracking a single finger touched in a corner region.
        case tracking(finger: TrackedFinger, corner: Corner)
        case cooldown(until: Date)
    }

    private(set) public var state: State = .idle
    private let sensitivity: SensitivityConfig

    public init(sensitivity: SensitivityConfig) {
        self.sensitivity = sensitivity
    }

    // MARK: - State inspection for tests

    public var isIdle: Bool { if case .idle = state { return true }; return false }
    public var isTracking: Bool { if case .tracking = state { return true }; return false }
    public var isCooldown: Bool { if case .cooldown = state { return true }; return false }

    // MARK: - Process frame

    public mutating func processFrame(_ frame: TouchFrame) -> RecognitionResult {
        let now = frame.timestamp
        let tolerance = Float(sensitivity.movementTolerance)
        let tapMaxSec = sensitivity.tapMaxDurationMs / 1000.0
        let cooldownSec = sensitivity.debounceCooldownMs / 1000.0
        let regionSize = Float(sensitivity.cornerRegionSize)

        let active = frame.points.filter { $0.state == .touching || $0.state == .making }

        switch state {
        case .idle:
            guard active.count == 1 else { return .empty }
            let p = active[0]
            guard let corner = Self.corner(of: p.position, regionSize: regionSize) else {
                return .empty
            }
            state = .tracking(
                finger: TrackedFinger(id: p.id, position: p.position, time: now),
                corner: corner
            )
            return .empty

        case .tracking(var finger, let corner):
            // Second finger appeared → this is not a single-finger tap. Abort.
            if active.count > 1 {
                state = .idle
                return .empty
            }

            // Finger still present
            if let p = active.first, p.id == finger.id {
                finger.lastPosition = p.position
                finger.lastTime = now

                if !finger.isStationary(tolerance: tolerance) {
                    // Enter cooldown (not idle) so the same ongoing touch cannot
                    // immediately re-enter tracking on the next frame.
                    state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                    return .rejected([RejectionReason(
                        recognizer: "CornerTap",
                        parameter: "movementTolerance",
                        threshold: sensitivity.movementTolerance,
                        actual: Double(finger.displacement),
                        label: "fingerMoved"
                    )])
                }

                if now.timeIntervalSince(finger.startTime) > tapMaxSec {
                    state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                    return .rejected([RejectionReason(
                        recognizer: "CornerTap",
                        parameter: "tapMaxDurationMs",
                        threshold: sensitivity.tapMaxDurationMs,
                        actual: now.timeIntervalSince(finger.startTime) * 1000.0,
                        label: "tapTooSlow"
                    )])
                }

                state = .tracking(finger: finger, corner: corner)
                return .empty
            }

            // Finger lifted (either 0 active, or different id).
            let duration = now.timeIntervalSince(finger.startTime)
            if duration <= tapMaxSec {
                state = .cooldown(until: now.addingTimeInterval(cooldownSec))
                return .recognized(Self.gestureType(for: corner))
            } else {
                state = .idle
                return .rejected([RejectionReason(
                    recognizer: "CornerTap",
                    parameter: "tapMaxDurationMs",
                    threshold: sensitivity.tapMaxDurationMs,
                    actual: duration * 1000.0,
                    label: "tapTooSlow"
                )])
            }

        case .cooldown(let until):
            if now < until { return .empty }
            // Cooldown expired — inline idle-state handling to avoid recursive
            // re-entry into this mutating method.
            state = .idle
            guard active.count == 1 else { return .empty }
            let p = active[0]
            guard let corner = Self.corner(of: p.position, regionSize: regionSize) else {
                return .empty
            }
            state = .tracking(
                finger: TrackedFinger(id: p.id, position: p.position, time: now),
                corner: corner
            )
            return .empty
        }
    }

    // MARK: - Helpers

    /// Returns the corner the given normalized position falls into, or `nil` if
    /// the position is outside every corner region.
    ///
    /// Corners are square regions of side `regionSize` anchored at each corner.
    /// OMS convention: `+y` points upward, so `top` = high y, `bottom` = low y.
    static func corner(of position: SIMD2<Float>, regionSize: Float) -> Corner? {
        let inLeft = position.x < regionSize
        let inRight = position.x > (1.0 - regionSize)
        let inBottom = position.y < regionSize
        let inTop = position.y > (1.0 - regionSize)

        if inLeft && inTop { return .topLeft }
        if inRight && inTop { return .topRight }
        if inLeft && inBottom { return .bottomLeft }
        if inRight && inBottom { return .bottomRight }
        return nil
    }

    private static func gestureType(for corner: Corner) -> GestureType {
        switch corner {
        case .topLeft:     return .cornerTapTopLeft
        case .topRight:    return .cornerTapTopRight
        case .bottomLeft:  return .cornerTapBottomLeft
        case .bottomRight: return .cornerTapBottomRight
        }
    }
}
