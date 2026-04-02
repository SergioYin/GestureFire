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
    /// Whether the user has completed the onboarding wizard.
    public var hasCompletedOnboarding: Bool
    /// Whether sound feedback plays on gesture recognition.
    public var soundEnabled: Bool
    /// Sound volume (0.0–1.0).
    public var soundVolume: Float
    /// Whether to launch at login via SMAppService.
    public var launchAtLogin: Bool
    /// Whether to show the floating status panel on gesture recognition.
    public var statusPanelEnabled: Bool

    public static let defaults = GestureFireConfig(
        version: 2,
        gestures: [:],
        sensitivity: .defaults,
        hasCompletedOnboarding: false,
        soundEnabled: true,
        soundVolume: 0.5,
        launchAtLogin: false,
        statusPanelEnabled: true
    )

    public init(
        version: Int = 2,
        gestures: [String: KeyShortcut] = [:],
        sensitivity: SensitivityConfig = .defaults,
        hasCompletedOnboarding: Bool = false,
        soundEnabled: Bool = true,
        soundVolume: Float = 0.5,
        launchAtLogin: Bool = false,
        statusPanelEnabled: Bool = true
    ) {
        self.version = version
        self.gestures = gestures
        self.sensitivity = sensitivity
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.soundEnabled = soundEnabled
        self.soundVolume = soundVolume
        self.launchAtLogin = launchAtLogin
        self.statusPanelEnabled = statusPanelEnabled
    }

    /// Look up the shortcut mapped to a gesture type.
    public func shortcut(for gesture: GestureType) -> KeyShortcut? {
        gestures[gesture.rawValue]
    }

    // MARK: - Codable with version defaulting

    private enum CodingKeys: String, CodingKey {
        case version, gestures, sensitivity, hasCompletedOnboarding
        case soundEnabled, soundVolume, launchAtLogin, statusPanelEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        gestures = try container.decodeIfPresent([String: KeyShortcut].self, forKey: .gestures) ?? [:]
        sensitivity = try container.decodeIfPresent(SensitivityConfig.self, forKey: .sensitivity) ?? .defaults
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        soundVolume = try container.decodeIfPresent(Float.self, forKey: .soundVolume) ?? 0.5
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        statusPanelEnabled = try container.decodeIfPresent(Bool.self, forKey: .statusPanelEnabled) ?? true
    }
}
