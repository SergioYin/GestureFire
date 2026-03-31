import Foundation
import GestureFireTypes

/// Handles config version detection and migration.
/// v0.2 configs have no version field (detected as version 1).
/// v1 configs start at version 2.
public enum ConfigMigration {

    /// Load and migrate config data to the current format.
    public static func migrate(from data: Data) throws -> GestureFireConfig {
        // Decode with version defaulting (missing version = 1)
        var config = try JSONDecoder().decode(GestureFireConfig.self, from: data)

        // Apply migrations
        if config.version < 2 {
            config = migrateV1ToV2(config)
        }

        return config
    }

    /// Migrate v0.2 (version 1) config to v1 (version 2).
    /// Preserves gesture mappings and sensitivity values as-is.
    /// Missing v1 fields get defaults via SensitivityConfig's Codable.
    private static func migrateV1ToV2(_ config: GestureFireConfig) -> GestureFireConfig {
        GestureFireConfig(
            version: 2,
            gestures: config.gestures,
            sensitivity: config.sensitivity
        )
    }
}
