/// Gesture types recognized by GestureFire.
/// Phase 1: TipTap only. Expanded in later phases.
public enum GestureType: String, Sendable, Codable, CaseIterable, Hashable {
    // Phase 1: TipTap (hold one finger, tap another in a direction)
    case tipTapLeft
    case tipTapRight
    case tipTapUp
    case tipTapDown
}

extension GestureType {
    public var displayName: String {
        switch self {
        case .tipTapLeft: "TipTap Left"
        case .tipTapRight: "TipTap Right"
        case .tipTapUp: "TipTap Up"
        case .tipTapDown: "TipTap Down"
        }
    }
}
