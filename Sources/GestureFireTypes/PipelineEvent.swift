import Foundation

/// A snapshot of the last thing that happened in the gesture pipeline.
/// Shown in diagnostics so users can see where things are stuck.
public enum PipelineEvent: Sendable, Equatable {
    /// Touch frame received from trackpad. detail = finger states (e.g. "touching, making")
    case frameReceived(fingerCount: Int, timestamp: Date, detail: String = "")
    /// Gesture recognized successfully.
    case recognized(gesture: GestureType, timestamp: Date)
    /// Gesture recognition rejected with reason.
    case rejected(reason: String, timestamp: Date)
    /// Recognized gesture but no shortcut mapped.
    case unmapped(gesture: GestureType, timestamp: Date)
    /// Shortcut fired successfully.
    case shortcutFired(gesture: GestureType, shortcut: String, timestamp: Date)
    /// Shortcut fire failed.
    case shortcutFailed(gesture: GestureType, shortcut: String, timestamp: Date)

    public var timestamp: Date {
        switch self {
        case .frameReceived(_, let t, _),
             .recognized(_, let t),
             .rejected(_, let t),
             .unmapped(_, let t),
             .shortcutFired(_, _, let t),
             .shortcutFailed(_, _, let t):
            t
        }
    }

    public var displayDescription: String {
        switch self {
        case .frameReceived(let count, _, let detail):
            if detail.isEmpty {
                "Touch: \(count) fingers"
            } else {
                "Touch: \(count) fingers [\(detail)]"
            }
        case .recognized(let gesture, _):
            "Recognized: \(gesture.displayName)"
        case .rejected(let reason, _):
            "Rejected: \(reason)"
        case .unmapped(let gesture, _):
            "Recognized \(gesture.displayName) — no shortcut mapped"
        case .shortcutFired(let gesture, let shortcut, _):
            "Fired \(shortcut) for \(gesture.displayName)"
        case .shortcutFailed(let gesture, let shortcut, _):
            "Failed to fire \(shortcut) for \(gesture.displayName)"
        }
    }

    public var systemImage: String {
        switch self {
        case .frameReceived: "hand.point.up"
        case .recognized: "checkmark.circle"
        case .rejected: "xmark.circle"
        case .unmapped: "questionmark.circle"
        case .shortcutFired: "keyboard"
        case .shortcutFailed: "keyboard.badge.exclamationmark"
        }
    }

    public enum SemanticColor: String, Sendable {
        case secondary, blue, orange, yellow, green, red
    }

    public var semanticColor: SemanticColor {
        switch self {
        case .frameReceived: .secondary
        case .recognized: .blue
        case .rejected: .orange
        case .unmapped: .yellow
        case .shortcutFired: .green
        case .shortcutFailed: .red
        }
    }

    /// Legacy string accessor for backward compatibility.
    public var color: String { semanticColor.rawValue }
}
