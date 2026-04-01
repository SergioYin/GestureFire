import Foundation

/// Real state of the gesture engine, replacing the boolean isEnabled.
/// Menu bar and diagnostics both reflect this.
public enum EngineState: Sendable, Equatable {
    /// User has not started the engine.
    case disabled
    /// Accessibility permission not granted — cannot function.
    case needsPermission
    /// OMS listener starting, waiting for first touch frame.
    case starting
    /// Fully operational — receiving frames and recognizing gestures.
    case running
    /// Failed to start (e.g. OMS listener failed).
    case failed(String)

    public var isOperational: Bool {
        if case .running = self { return true }
        return false
    }

    public var displayLabel: String {
        switch self {
        case .disabled: "Disabled"
        case .needsPermission: "Needs Permission"
        case .starting: "Starting..."
        case .running: "Running"
        case .failed(let reason): "Failed: \(reason)"
        }
    }

    public var systemImage: String {
        switch self {
        case .disabled: "hand.tap"
        case .needsPermission: "exclamationmark.triangle"
        case .starting: "hourglass"
        case .running: "hand.tap.fill"
        case .failed: "xmark.circle"
        }
    }
}
