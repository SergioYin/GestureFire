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
public struct TouchPoint: Sendable, Equatable, Codable {
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

    // MARK: - Codable (SIMD2<Float> encoded as [x, y] array)

    private enum CodingKeys: String, CodingKey {
        case id, position, state, timestamp
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode([position.x, position.y], forKey: .position)
        try container.encode(state, forKey: .state)
        try container.encode(timestamp, forKey: .timestamp)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int32.self, forKey: .id)
        let pos = try container.decode([Float].self, forKey: .position)
        guard pos.count == 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .position, in: container,
                debugDescription: "Position must be [x, y] array with 2 elements"
            )
        }
        position = SIMD2(pos[0], pos[1])
        state = try container.decode(TouchState.self, forKey: .state)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
}

/// A frame of touch data from the trackpad. The `timestamp` is the
/// authoritative time source for all recognizer timing decisions.
public struct TouchFrame: Sendable, Equatable, Codable {
    public let points: [TouchPoint]
    /// Authoritative time source — all timing decisions use this, never Date().
    public let timestamp: Date

    public init(points: [TouchPoint], timestamp: Date) {
        self.points = points
        self.timestamp = timestamp
    }
}
