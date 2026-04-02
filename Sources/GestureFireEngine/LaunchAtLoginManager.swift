import Foundation
import os
import ServiceManagement

/// Manages launch-at-login via SMAppService.
/// Wraps the system API with error reporting for UI consumption.
@MainActor
public final class LaunchAtLoginManager {

    public enum Status: Equatable, Sendable {
        case enabled
        case notRegistered
        case requiresApproval
        case unknown(String)
    }

    private static let logger = Logger(subsystem: "com.gesturefire", category: "launch-at-login")

    public init() {}

    /// Current status of the launch-at-login registration.
    public var status: Status {
        mapStatus(SMAppService.mainApp.status)
    }

    /// Enable launch-at-login. Returns nil on success, error message on failure.
    public func enable() -> String? {
        do {
            try SMAppService.mainApp.register()
            Self.logger.info("Launch-at-login enabled")
            return nil
        } catch {
            let msg = "Failed to enable launch-at-login: \(error.localizedDescription)"
            Self.logger.error("\(msg)")
            return msg
        }
    }

    /// Disable launch-at-login. Returns nil on success, error message on failure.
    public func disable() -> String? {
        do {
            try SMAppService.mainApp.unregister()
            Self.logger.info("Launch-at-login disabled")
            return nil
        } catch {
            let msg = "Failed to disable launch-at-login: \(error.localizedDescription)"
            Self.logger.error("\(msg)")
            return msg
        }
    }

    /// Set launch-at-login to match config value. Returns error message if any.
    public func sync(with enabled: Bool) -> String? {
        if enabled {
            return enable()
        } else {
            return disable()
        }
    }

    private func mapStatus(_ status: SMAppService.Status) -> Status {
        switch status {
        case .enabled: .enabled
        case .notRegistered: .notRegistered
        case .requiresApproval: .requiresApproval
        @unknown default: .unknown("\(status)")
        }
    }
}
