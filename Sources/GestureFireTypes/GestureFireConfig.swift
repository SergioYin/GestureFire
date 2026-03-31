import Foundation

/// Top-level configuration for GestureFire.
/// `version` field enables schema migration. Missing version → v0.2 format (version 1).
public struct GestureFireConfig: Sendable, Codable, Equatable {
    /// Schema version. v0.2 configs have no version field → decoded as 1.
    /// v1 starts at version 2.
    public var version: Int
    /// Gesture → shortcut mappings. Key is GestureType.rawValue.
    public var gestures: [String: KeyShortcut]
    public var sensitivity: SensitivityConfig

    public static let defaults = GestureFireConfig(
        version: 2,
        gestures: [:],
        sensitivity: .defaults
    )

    public init(version: Int = 2, gestures: [String: KeyShortcut] = [:], sensitivity: SensitivityConfig = .defaults) {
        self.version = version
        self.gestures = gestures
        self.sensitivity = sensitivity
    }

    /// Look up the shortcut mapped to a gesture type.
    public func shortcut(for gesture: GestureType) -> KeyShortcut? {
        gestures[gesture.rawValue]
    }

    // MARK: - Codable with version defaulting

    private enum CodingKeys: String, CodingKey {
        case version, gestures, sensitivity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        gestures = try container.decodeIfPresent([String: KeyShortcut].self, forKey: .gestures) ?? [:]
        sensitivity = try container.decodeIfPresent(SensitivityConfig.self, forKey: .sensitivity) ?? .defaults
    }
}
