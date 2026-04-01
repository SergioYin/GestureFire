import Testing
@testable import GestureFireConfig
import GestureFireTypes

@Suite("GesturePreset")
struct GesturePresetTests {
    @Test("All presets have unique IDs")
    func uniqueIds() {
        let ids = GesturePreset.allPresets.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("At least 3 presets available")
    func minimumPresets() {
        #expect(GesturePreset.allPresets.count >= 3)
    }

    @Test("Browser preset maps all 4 TipTap directions")
    func browserPresetComplete() {
        let preset = GesturePreset.browser
        for gesture in GestureType.allCases {
            #expect(preset.gestures[gesture.rawValue] != nil, "Missing mapping for \(gesture)")
        }
    }

    @Test("IDE preset maps all 4 TipTap directions")
    func idePresetComplete() {
        let preset = GesturePreset.ide
        for gesture in GestureType.allCases {
            #expect(preset.gestures[gesture.rawValue] != nil, "Missing mapping for \(gesture)")
        }
    }

    @Test("Custom preset has empty gestures")
    func customPresetEmpty() {
        #expect(GesturePreset.custom.gestures.isEmpty)
    }

    @Test("All presets have non-empty display names and icons")
    func presetsHaveMetadata() {
        for preset in GesturePreset.allPresets {
            #expect(!preset.displayName.isEmpty)
            #expect(!preset.icon.isEmpty)
            #expect(!preset.description.isEmpty)
        }
    }
}
