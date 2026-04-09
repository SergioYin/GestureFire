import Foundation

/// All 14 sensitivity parameters. Values are direct thresholds — no hidden multipliers.
/// Parameters 1–10 are shared across recognizers; parameters 11–14 are dedicated
/// to multi-finger recognizers where shared thresholds proved insufficient on real hardware.
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

    // Multi-finger dedicated (Phase 3 hardening round 2)
    /// Max time from first finger touchdown to all lifted, for 3/4/5-finger taps.
    public var multiFingerTapDurationMs: Double
    /// Max per-finger displacement allowed during a multi-finger tap.
    public var multiFingerMovementTolerance: Double
    /// Max pairwise distance between any two fingers in a multi-finger tap cluster.
    public var multiFingerSpreadMax: Double
    /// Max distance any finger may be from the cluster centroid during a swipe.
    public var swipeClusterTolerance: Double

    public static let defaults = SensitivityConfig(
        holdThresholdMs: 200,
        tapMaxDurationMs: 400,
        movementTolerance: 0.08,
        debounceCooldownMs: 500,
        swipeMinDistance: 0.08,
        cornerRegionSize: 0.25,
        fingerProximityThreshold: 0.20,
        swipeMaxDurationMs: 800,
        directionAngleTolerance: 30.0,
        tapGroupingWindowMs: 250,
        multiFingerTapDurationMs: 600,
        multiFingerMovementTolerance: 0.12,
        multiFingerSpreadMax: 0.70,
        swipeClusterTolerance: 0.30
    )

    public init(
        holdThresholdMs: Double = 200,
        tapMaxDurationMs: Double = 400,
        movementTolerance: Double = 0.08,
        debounceCooldownMs: Double = 500,
        swipeMinDistance: Double = 0.08,
        cornerRegionSize: Double = 0.25,
        fingerProximityThreshold: Double = 0.20,
        swipeMaxDurationMs: Double = 800,
        directionAngleTolerance: Double = 30.0,
        tapGroupingWindowMs: Double = 250,
        multiFingerTapDurationMs: Double = 600,
        multiFingerMovementTolerance: Double = 0.12,
        multiFingerSpreadMax: Double = 0.70,
        swipeClusterTolerance: Double = 0.30
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
        self.multiFingerTapDurationMs = multiFingerTapDurationMs
        self.multiFingerMovementTolerance = multiFingerMovementTolerance
        self.multiFingerSpreadMax = multiFingerSpreadMax
        self.swipeClusterTolerance = swipeClusterTolerance
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
        case multiFingerTapDurationMs
        case multiFingerMovementTolerance
        case multiFingerSpreadMax
        case swipeClusterTolerance
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
        case .multiFingerTapDurationMs: multiFingerTapDurationMs
        case .multiFingerMovementTolerance: multiFingerMovementTolerance
        case .multiFingerSpreadMax: multiFingerSpreadMax
        case .swipeClusterTolerance: swipeClusterTolerance
        }
    }

    // MARK: - Codable (with defaults for missing fields)

    private enum CodingKeys: String, CodingKey {
        case holdThresholdMs, tapMaxDurationMs, movementTolerance, debounceCooldownMs
        case swipeMinDistance, cornerRegionSize
        case fingerProximityThreshold, swipeMaxDurationMs, directionAngleTolerance, tapGroupingWindowMs
        case multiFingerTapDurationMs, multiFingerMovementTolerance, multiFingerSpreadMax, swipeClusterTolerance
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
        case .multiFingerTapDurationMs: copy.multiFingerTapDurationMs = value
        case .multiFingerMovementTolerance: copy.multiFingerMovementTolerance = value
        case .multiFingerSpreadMax: copy.multiFingerSpreadMax = value
        case .swipeClusterTolerance: copy.swipeClusterTolerance = value
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
        multiFingerTapDurationMs = try c.decodeIfPresent(Double.self, forKey: .multiFingerTapDurationMs) ?? d.multiFingerTapDurationMs
        multiFingerMovementTolerance = try c.decodeIfPresent(Double.self, forKey: .multiFingerMovementTolerance) ?? d.multiFingerMovementTolerance
        multiFingerSpreadMax = try c.decodeIfPresent(Double.self, forKey: .multiFingerSpreadMax) ?? d.multiFingerSpreadMax
        swipeClusterTolerance = try c.decodeIfPresent(Double.self, forKey: .swipeClusterTolerance) ?? d.swipeClusterTolerance
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
        case .multiFingerTapDurationMs: ParameterBounds(min: 300, max: 1200)
        case .multiFingerMovementTolerance: ParameterBounds(min: 0.05, max: 0.25)
        case .multiFingerSpreadMax: ParameterBounds(min: 0.30, max: 1.00)
        case .swipeClusterTolerance: ParameterBounds(min: 0.10, max: 0.50)
        }
    }
}
