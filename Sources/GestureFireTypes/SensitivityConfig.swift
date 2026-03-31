import Foundation

/// All 10 sensitivity parameters. All fields present from Phase 1 (Plan A).
/// Phase 1 UI shows TipTap subset; later phases expose more.
/// Values are direct thresholds — no hidden multipliers.
public struct SensitivityConfig: Sendable, Equatable {
    // Preserved from v0.2 (with hidden multipliers removed)
    public var holdThresholdMs: Double
    public var tapMaxDurationMs: Double
    public var movementTolerance: Double
    public var debounceCooldownMs: Double
    public var swipeMinDistance: Double
    public var cornerRegionSize: Double

    // New in v1
    public var fingerProximityThreshold: Double
    public var swipeMaxDurationMs: Double
    public var directionAngleTolerance: Double
    public var tapGroupingWindowMs: Double

    public static let defaults = SensitivityConfig(
        holdThresholdMs: 200,
        tapMaxDurationMs: 300,
        movementTolerance: 0.06,
        debounceCooldownMs: 500,
        swipeMinDistance: 0.08,
        cornerRegionSize: 0.25,
        fingerProximityThreshold: 0.15,
        swipeMaxDurationMs: 800,
        directionAngleTolerance: 30.0,
        tapGroupingWindowMs: 200
    )

    public init(
        holdThresholdMs: Double = 200,
        tapMaxDurationMs: Double = 300,
        movementTolerance: Double = 0.06,
        debounceCooldownMs: Double = 500,
        swipeMinDistance: Double = 0.08,
        cornerRegionSize: Double = 0.25,
        fingerProximityThreshold: Double = 0.15,
        swipeMaxDurationMs: Double = 800,
        directionAngleTolerance: Double = 30.0,
        tapGroupingWindowMs: Double = 200
    ) {
        self.holdThresholdMs = holdThresholdMs
        self.tapMaxDurationMs = tapMaxDurationMs
        self.movementTolerance = movementTolerance
        self.debounceCooldownMs = debounceCooldownMs
        self.swipeMinDistance = swipeMinDistance
        self.cornerRegionSize = cornerRegionSize
        self.fingerProximityThreshold = fingerProximityThreshold
        self.swipeMaxDurationMs = swipeMaxDurationMs
        self.directionAngleTolerance = directionAngleTolerance
        self.tapGroupingWindowMs = tapGroupingWindowMs
    }

    /// Parameter names for dynamic access (feedback loops, calibration).
    public enum Parameter: String, Sendable, CaseIterable {
        case holdThresholdMs
        case tapMaxDurationMs
        case movementTolerance
        case debounceCooldownMs
        case swipeMinDistance
        case cornerRegionSize
        case fingerProximityThreshold
        case swipeMaxDurationMs
        case directionAngleTolerance
        case tapGroupingWindowMs
    }

    /// Dynamic value access by parameter name.
    public func value(for parameter: Parameter) -> Double {
        switch parameter {
        case .holdThresholdMs: holdThresholdMs
        case .tapMaxDurationMs: tapMaxDurationMs
        case .movementTolerance: movementTolerance
        case .debounceCooldownMs: debounceCooldownMs
        case .swipeMinDistance: swipeMinDistance
        case .cornerRegionSize: cornerRegionSize
        case .fingerProximityThreshold: fingerProximityThreshold
        case .swipeMaxDurationMs: swipeMaxDurationMs
        case .directionAngleTolerance: directionAngleTolerance
        case .tapGroupingWindowMs: tapGroupingWindowMs
        }
    }

    // MARK: - Codable (with defaults for missing fields)

    private enum CodingKeys: String, CodingKey {
        case holdThresholdMs, tapMaxDurationMs, movementTolerance, debounceCooldownMs
        case swipeMinDistance, cornerRegionSize
        case fingerProximityThreshold, swipeMaxDurationMs, directionAngleTolerance, tapGroupingWindowMs
    }

    /// Returns a new config with one parameter updated (immutable).
    public func withValue(_ value: Double, for parameter: Parameter) -> SensitivityConfig {
        var copy = self
        switch parameter {
        case .holdThresholdMs: copy.holdThresholdMs = value
        case .tapMaxDurationMs: copy.tapMaxDurationMs = value
        case .movementTolerance: copy.movementTolerance = value
        case .debounceCooldownMs: copy.debounceCooldownMs = value
        case .swipeMinDistance: copy.swipeMinDistance = value
        case .cornerRegionSize: copy.cornerRegionSize = value
        case .fingerProximityThreshold: copy.fingerProximityThreshold = value
        case .swipeMaxDurationMs: copy.swipeMaxDurationMs = value
        case .directionAngleTolerance: copy.directionAngleTolerance = value
        case .tapGroupingWindowMs: copy.tapGroupingWindowMs = value
        }
        return copy
    }
}

extension SensitivityConfig: Codable {
    public init(from decoder: Decoder) throws {
        let d = SensitivityConfig.defaults
        let c = try decoder.container(keyedBy: CodingKeys.self)
        holdThresholdMs = try c.decodeIfPresent(Double.self, forKey: .holdThresholdMs) ?? d.holdThresholdMs
        tapMaxDurationMs = try c.decodeIfPresent(Double.self, forKey: .tapMaxDurationMs) ?? d.tapMaxDurationMs
        movementTolerance = try c.decodeIfPresent(Double.self, forKey: .movementTolerance) ?? d.movementTolerance
        debounceCooldownMs = try c.decodeIfPresent(Double.self, forKey: .debounceCooldownMs) ?? d.debounceCooldownMs
        swipeMinDistance = try c.decodeIfPresent(Double.self, forKey: .swipeMinDistance) ?? d.swipeMinDistance
        cornerRegionSize = try c.decodeIfPresent(Double.self, forKey: .cornerRegionSize) ?? d.cornerRegionSize
        fingerProximityThreshold = try c.decodeIfPresent(Double.self, forKey: .fingerProximityThreshold) ?? d.fingerProximityThreshold
        swipeMaxDurationMs = try c.decodeIfPresent(Double.self, forKey: .swipeMaxDurationMs) ?? d.swipeMaxDurationMs
        directionAngleTolerance = try c.decodeIfPresent(Double.self, forKey: .directionAngleTolerance) ?? d.directionAngleTolerance
        tapGroupingWindowMs = try c.decodeIfPresent(Double.self, forKey: .tapGroupingWindowMs) ?? d.tapGroupingWindowMs
    }
}

/// Min/max bounds for each sensitivity parameter.
public struct ParameterBounds: Sendable {
    public let min: Double
    public let max: Double

    public static func bounds(for parameter: SensitivityConfig.Parameter) -> ParameterBounds {
        switch parameter {
        case .holdThresholdMs: ParameterBounds(min: 80, max: 500)
        case .tapMaxDurationMs: ParameterBounds(min: 150, max: 800)
        case .movementTolerance: ParameterBounds(min: 0.01, max: 0.15)
        case .debounceCooldownMs: ParameterBounds(min: 100, max: 1000)
        case .swipeMinDistance: ParameterBounds(min: 0.03, max: 0.20)
        case .cornerRegionSize: ParameterBounds(min: 0.15, max: 0.40)
        case .fingerProximityThreshold: ParameterBounds(min: 0.05, max: 0.30)
        case .swipeMaxDurationMs: ParameterBounds(min: 300, max: 2000)
        case .directionAngleTolerance: ParameterBounds(min: 15, max: 45)
        case .tapGroupingWindowMs: ParameterBounds(min: 50, max: 500)
        }
    }
}
