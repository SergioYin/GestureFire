import Foundation
import GestureFireTypes
import Observation
import os

/// Observable config store for SwiftUI binding.
/// Loads on init, saves on every change.
@MainActor
@Observable
public final class ConfigStore {
    public private(set) var config: GestureFireConfig
    private let persistence: any ConfigPersisting

    public init(persistence: any ConfigPersisting = FileConfigPersistence()) {
        self.persistence = persistence
        self.config = (try? persistence.load()) ?? .defaults
    }

    /// Update config and persist.
    public func update(_ transform: (inout GestureFireConfig) -> Void) {
        var copy = config
        transform(&copy)
        config = copy
        do {
            try persistence.save(config)
        } catch {
            Self.logger.error("Failed to save config: \(error)")
        }
    }

    private static let logger = Logger(subsystem: "com.gesturefire", category: "config")

    /// Get a snapshot for passing to actors (value type, safe to cross boundaries).
    public var snapshot: GestureFireConfig { config }
}
