import Foundation
import GestureFireTypes

/// A finger being tracked by a recognizer. Value type.
public struct TrackedFinger: Sendable, Equatable {
    public let id: Int32
    public let startPosition: SIMD2<Float>
    public let startTime: Date
    public var lastPosition: SIMD2<Float>
    public var lastTime: Date

    public init(id: Int32, position: SIMD2<Float>, time: Date) {
        self.id = id
        self.startPosition = position
        self.startTime = time
        self.lastPosition = position
        self.lastTime = time
    }

    /// Total displacement from start to current position.
    public var displacement: Float {
        let diff = lastPosition - startPosition
        return (diff.x * diff.x + diff.y * diff.y).squareRoot()
    }

    /// Duration from first appearance to last update.
    public var duration: TimeInterval {
        lastTime.timeIntervalSince(startTime)
    }

    /// Whether the finger has stayed within a tolerance of its start position.
    public func isStationary(tolerance: Float) -> Bool {
        displacement <= tolerance
    }
}

/// A finger that was lifted (appeared and disappeared quickly = potential tap).
public struct LiftedFinger: Sendable, Equatable {
    public let finger: TrackedFinger
    public let liftTime: Date

    public init(finger: TrackedFinger, liftTime: Date) {
        self.finger = finger
        self.liftTime = liftTime
    }
}
