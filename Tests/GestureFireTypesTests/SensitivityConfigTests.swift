import Foundation
import Testing
@testable import GestureFireTypes

@Suite("SensitivityConfig defaults")
struct SensitivityConfigDefaultsTests {

    @Test("Default values match spec")
    func defaults() {
        let config = SensitivityConfig.defaults
        #expect(config.holdThresholdMs == 200)
        #expect(config.tapMaxDurationMs == 300)
        #expect(config.movementTolerance == 0.06)
        #expect(config.debounceCooldownMs == 500)
        #expect(config.swipeMinDistance == 0.08)
        #expect(config.cornerRegionSize == 0.25)
        #expect(config.fingerProximityThreshold == 0.15)
        #expect(config.swipeMaxDurationMs == 800)
        #expect(config.directionAngleTolerance == 30.0)
        #expect(config.tapGroupingWindowMs == 200)
    }

    @Test("Has exactly 10 parameters")
    func parameterCount() {
        #expect(SensitivityConfig.Parameter.allCases.count == 10)
    }
}

@Suite("SensitivityConfig dynamic access")
struct SensitivityConfigDynamicAccessTests {

    @Test("value(for:) returns correct values", arguments: SensitivityConfig.Parameter.allCases)
    func valueAccess(param: SensitivityConfig.Parameter) {
        let config = SensitivityConfig.defaults
        let value = config.value(for: param)
        #expect(value > 0)
    }

    @Test("withValue creates a new config with updated value")
    func withValue() {
        let original = SensitivityConfig.defaults
        let updated = original.withValue(150, for: .holdThresholdMs)
        #expect(updated.holdThresholdMs == 150)
        // Original unchanged (immutability)
        #expect(original.holdThresholdMs == 200)
    }

    @Test("withValue round-trip for all parameters", arguments: SensitivityConfig.Parameter.allCases)
    func withValueRoundTrip(param: SensitivityConfig.Parameter) {
        let config = SensitivityConfig.defaults
        let newValue = 42.0
        let updated = config.withValue(newValue, for: param)
        #expect(updated.value(for: param) == newValue)
    }
}

@Suite("SensitivityConfig bounds")
struct SensitivityConfigBoundsTests {

    @Test("Every parameter has bounds")
    func allParametersHaveBounds() {
        for param in SensitivityConfig.Parameter.allCases {
            let bounds = ParameterBounds.bounds(for: param)
            #expect(bounds.min < bounds.max)
        }
    }

    @Test("Default values are within bounds", arguments: SensitivityConfig.Parameter.allCases)
    func defaultsWithinBounds(param: SensitivityConfig.Parameter) {
        let config = SensitivityConfig.defaults
        let value = config.value(for: param)
        let bounds = ParameterBounds.bounds(for: param)
        #expect(value >= bounds.min)
        #expect(value <= bounds.max)
    }

    @Test("Specific bounds match spec")
    func specificBounds() {
        let hold = ParameterBounds.bounds(for: .holdThresholdMs)
        #expect(hold.min == 80)
        #expect(hold.max == 500)

        let angle = ParameterBounds.bounds(for: .directionAngleTolerance)
        #expect(angle.min == 15)
        #expect(angle.max == 45)
    }
}

@Suite("SensitivityConfig Codable")
struct SensitivityConfigCodableTests {

    @Test("Round-trip through JSON")
    func jsonRoundTrip() throws {
        let original = SensitivityConfig.defaults
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SensitivityConfig.self, from: data)
        #expect(original == decoded)
    }

    @Test("Partial JSON uses defaults for missing fields")
    func partialJSON() throws {
        let json = #"{"holdThresholdMs": 150}"#
        let config = try JSONDecoder().decode(SensitivityConfig.self, from: Data(json.utf8))
        #expect(config.holdThresholdMs == 150)
        #expect(config.tapMaxDurationMs == 300) // default
        #expect(config.directionAngleTolerance == 30.0) // default
    }
}
