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

    // Phase 3: multi-finger taps (3/4/5 fingers tap together)
    case multiFingerTap3
    case multiFingerTap4
    case multiFingerTap5

    // Phase 3: multi-finger swipes (3 or 4 fingers translating in a cardinal direction)
    case multiFingerSwipe3Left
    case multiFingerSwipe3Right
    case multiFingerSwipe3Up
    case multiFingerSwipe3Down
    case multiFingerSwipe4Left
    case multiFingerSwipe4Right
    case multiFingerSwipe4Up
    case multiFingerSwipe4Down
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
        case .multiFingerTap3: "3-Finger Tap"
        case .multiFingerTap4: "4-Finger Tap"
        case .multiFingerTap5: "5-Finger Tap"
        case .multiFingerSwipe3Left: "3-Finger Swipe Left"
        case .multiFingerSwipe3Right: "3-Finger Swipe Right"
        case .multiFingerSwipe3Up: "3-Finger Swipe Up"
        case .multiFingerSwipe3Down: "3-Finger Swipe Down"
        case .multiFingerSwipe4Left: "4-Finger Swipe Left"
        case .multiFingerSwipe4Right: "4-Finger Swipe Right"
        case .multiFingerSwipe4Up: "4-Finger Swipe Up"
        case .multiFingerSwipe4Down: "4-Finger Swipe Down"
        }
    }
}
