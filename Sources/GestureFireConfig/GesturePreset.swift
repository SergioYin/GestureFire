import Foundation
import GestureFireTypes

/// A bundled gesture-to-shortcut preset that users can select during onboarding.
public struct GesturePreset: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    /// SF Symbol name for the preset icon.
    public let icon: String
    /// Gesture → shortcut mappings (same shape as GestureFireConfig.gestures).
    public let gestures: [String: KeyShortcut]

    public init(
        id: String,
        displayName: String,
        description: String,
        icon: String,
        gestures: [String: KeyShortcut]
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.icon = icon
        self.gestures = gestures
    }
}

// MARK: - Bundled Presets

extension GesturePreset {
    /// Browser navigation: back/forward/new tab/close tab.
    public static let browser = GesturePreset(
        id: "browser",
        displayName: "Browser Navigation",
        description: "Navigate pages and manage tabs in your browser",
        icon: "globe",
        gestures: [
            GestureType.tipTapLeft.rawValue: try! KeyShortcut.parse("cmd+["),
            GestureType.tipTapRight.rawValue: try! KeyShortcut.parse("cmd+]"),
            GestureType.tipTapUp.rawValue: try! KeyShortcut.parse("cmd+t"),
            GestureType.tipTapDown.rawValue: try! KeyShortcut.parse("cmd+w"),
        ]
    )

    /// IDE shortcuts: run/stop/navigate back/forward.
    public static let ide = GesturePreset(
        id: "ide",
        displayName: "IDE Shortcuts",
        description: "Common shortcuts for Xcode and other IDEs",
        icon: "chevron.left.forwardslash.chevron.right",
        gestures: [
            GestureType.tipTapLeft.rawValue: try! KeyShortcut.parse("cmd+shift+["),
            GestureType.tipTapRight.rawValue: try! KeyShortcut.parse("cmd+shift+]"),
            GestureType.tipTapUp.rawValue: try! KeyShortcut.parse("cmd+r"),
            GestureType.tipTapDown.rawValue: try! KeyShortcut.parse("cmd+."),
        ]
    )

    /// Empty preset for users who want to configure everything manually.
    public static let custom = GesturePreset(
        id: "custom",
        displayName: "Custom",
        description: "Start with a blank slate and configure your own mappings",
        icon: "slider.horizontal.3",
        gestures: [:]
    )

    /// All available presets in display order.
    public static let allPresets: [GesturePreset] = [.browser, .ide, .custom]
}
