import Foundation
import Testing
@testable import GestureFireTypes

@Suite("GestureFireConfig")
struct GestureFireConfigTests {

    @Test("Default config has version 2 and empty gestures")
    func defaultConfig() {
        let config = GestureFireConfig.defaults
        #expect(config.version == 2)
        #expect(config.gestures.isEmpty)
        #expect(config.sensitivity == SensitivityConfig.defaults)
    }

    @Test("Round-trip through JSON")
    func jsonRoundTrip() throws {
        var config = GestureFireConfig.defaults
        config.gestures[GestureType.tipTapLeft.rawValue] = try KeyShortcut.parse("cmd+left")
        config.gestures[GestureType.tipTapRight.rawValue] = try KeyShortcut.parse("cmd+right")

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(GestureFireConfig.self, from: data)
        #expect(decoded.version == 2)
        #expect(decoded.gestures.count == 2)
        #expect(decoded.sensitivity == config.sensitivity)
    }

    @Test("shortcut(for:) returns mapped shortcut")
    func shortcutLookup() throws {
        var config = GestureFireConfig.defaults
        let shortcut = try KeyShortcut.parse("cmd+t")
        config.gestures[GestureType.tipTapUp.rawValue] = shortcut
        #expect(config.shortcut(for: .tipTapUp) == shortcut)
    }

    @Test("shortcut(for:) returns nil for unmapped gesture")
    func shortcutMissing() {
        let config = GestureFireConfig.defaults
        #expect(config.shortcut(for: .tipTapDown) == nil)
    }

    @Test("Config without version field decodes as version 1 (v0.2 compat)")
    func v02Compat() throws {
        let json = #"{"gestures":{},"sensitivity":{}}"#
        let config = try JSONDecoder().decode(GestureFireConfig.self, from: Data(json.utf8))
        #expect(config.version == 1)
    }

    @Test("Default config has hasCompletedOnboarding false")
    func defaultOnboardingFlag() {
        #expect(GestureFireConfig.defaults.hasCompletedOnboarding == false)
    }

    @Test("Config without hasCompletedOnboarding field defaults to false")
    func onboardingBackwardsCompat() throws {
        let json = #"{"version":2,"gestures":{},"sensitivity":{}}"#
        let config = try JSONDecoder().decode(GestureFireConfig.self, from: Data(json.utf8))
        #expect(config.hasCompletedOnboarding == false)
    }

    @Test("hasCompletedOnboarding round-trips through JSON")
    func onboardingRoundTrip() throws {
        var config = GestureFireConfig.defaults
        config.hasCompletedOnboarding = true
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(GestureFireConfig.self, from: data)
        #expect(decoded.hasCompletedOnboarding == true)
    }
}
