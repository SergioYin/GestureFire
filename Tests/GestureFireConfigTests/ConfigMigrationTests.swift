import Foundation
import Testing
import GestureFireTypes
@testable import GestureFireConfig

@Suite("ConfigMigration")
struct ConfigMigrationTests {

    @Test("v0.2 config (no version) migrates to v2")
    func migrateFromV02() throws {
        // v0.2 format: no version field, uses "keys" string in shortcuts
        let v02JSON = """
        {
            "gestures": {
                "tipTapLeft": "cmd+left",
                "tipTapRight": "cmd+right"
            },
            "sensitivity": {
                "holdThresholdMs": 200,
                "tapMaxDurationMs": 300,
                "movementTolerance": 0.02,
                "debounceCooldownMs": 500,
                "swipeMinDistance": 0.08,
                "cornerRegionSize": 0.25
            }
        }
        """

        let config = try ConfigMigration.migrate(from: Data(v02JSON.utf8))
        #expect(config.version == 2)
        #expect(config.gestures["tipTapLeft"]?.stringValue == "cmd+left")
        #expect(config.gestures["tipTapRight"]?.stringValue == "cmd+right")
        // v0.2 movementTolerance was 0.02 (with hidden 3x), keep raw value
        #expect(config.sensitivity.movementTolerance == 0.02)
        // New fields should get defaults
        #expect(config.sensitivity.directionAngleTolerance == 30.0)
        #expect(config.sensitivity.fingerProximityThreshold == 0.20)
    }

    @Test("v2 config passes through unchanged")
    func v2Passthrough() throws {
        let v2JSON = """
        {
            "version": 2,
            "gestures": {"tipTapUp": "cmd+up"},
            "sensitivity": {"holdThresholdMs": 180}
        }
        """
        let config = try ConfigMigration.migrate(from: Data(v2JSON.utf8))
        #expect(config.version == 2)
        #expect(config.gestures["tipTapUp"]?.stringValue == "cmd+up")
        #expect(config.sensitivity.holdThresholdMs == 180)
    }

    @Test("Empty JSON migrates to defaults")
    func emptyJSON() throws {
        let config = try ConfigMigration.migrate(from: Data("{}".utf8))
        #expect(config.version == 2)
        #expect(config.gestures.isEmpty)
    }
}
