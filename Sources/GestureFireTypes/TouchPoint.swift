import Foundation

/// State of an individual touch point on the trackpad.
/// Maps to OMS's OMSState values.
public enum TouchState: String, Sendable, Codable {
    case notTouching
    case starting
    case hovering
    case making      // finger making contact
    case touching    // finger fully touching
    case breaking    // finger starting to lift
    case lingering   // finger lingering after lift
    case leaving     // finger leaving trackpad
}

/// A single touch point on the trackpad, abstracted from OMS.
public struct TouchPoint: Sendable, Equatable {
    public let id: Int32
    /// Normalized position in 0...1 range.
    public let position: SIMD2<Float>
    public let state: TouchState
    public let timestamp: Date

    public init(id: Int32, position: SIMD2<Float>, state: TouchState, timestamp: Date) {
        self.id = id
        self.position = position
        self.state = state
        self.timestamp = timestamp
    }
}

/// A frame of touch data from the trackpad. The `timestamp` is the
/// authoritative time source for all recognizer timing decisions.
public struct TouchFrame: Sendable, Equatable {
    public let points: [TouchPoint]
    /// Authoritative time source — all timing decisions use this, never Date().
    public let timestamp: Date

    public init(points: [TouchPoint], timestamp: Date) {
        self.points = points
        self.timestamp = timestamp
    }
}
