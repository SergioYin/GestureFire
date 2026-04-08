/// Gesture types recognized by GestureFire.
/// Phase 1: TipTap only. Phase 3 adds corner taps, multi-finger taps,
/// and multi-finger swipes. New cases ship alongside the recognizer
/// that emits them, not all at once.
public enum GestureType: String, Sendable, Codable, CaseIterable, Hashable {
    // Phase 1: TipTap (hold one finger, tap another in a direction)
    case tipTapLeft
    case tipTapRight
    case tipTapUp
    case tipTapDown

    // Phase 3: corner taps (single tap in a corner region)
    case cornerTapTopLeft
    case cornerTapTopRight
    case cornerTapBottomLeft
    case cornerTapBottomRight
}

extension GestureType {
    public var displayName: String {
        switch self {
        case .tipTapLeft: "TipTap Left"
        case .tipTapRight: "TipTap Right"
        case .tipTapUp: "TipTap Up"
        case .tipTapDown: "TipTap Down"
        case .cornerTapTopLeft: "Corner Tap Top-Left"
        case .cornerTapTopRight: "Corner Tap Top-Right"
        case .cornerTapBottomLeft: "Corner Tap Bottom-Left"
        case .cornerTapBottomRight: "Corner Tap Bottom-Right"
        }
    }
}
