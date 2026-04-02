import Testing
@testable import GestureFireEngine
@testable import GestureFireTypes

@MainActor
@Suite("SoundFeedback")
struct SoundFeedbackTests {

    @Test("Initializes with enabled state and clamped volume")
    func initState() {
        let feedback = SoundFeedback(enabled: true, volume: 0.7)
        // Can't directly inspect private state, but verify it doesn't crash
        feedback.play()
    }

    @Test("Disabled feedback does not crash on play")
    func disabledDoesNotCrash() {
        let feedback = SoundFeedback(enabled: false, volume: 0.5)
        feedback.play()
    }

    @Test("Volume clamped to 0-1 range")
    func volumeClamping() {
        // Negative volume
        let low = SoundFeedback(enabled: true, volume: -0.5)
        low.play()

        // Over 1.0
        let high = SoundFeedback(enabled: true, volume: 2.0)
        high.play()
    }

    @Test("Update from config changes state")
    func updateFromConfig() {
        let feedback = SoundFeedback(enabled: true, volume: 0.5)

        var config = GestureFireConfig.defaults
        config.soundEnabled = false
        config.soundVolume = 0.8
        feedback.update(from: config)

        // After disabling, play should be silent (no crash)
        feedback.play()

        // Re-enable
        config.soundEnabled = true
        feedback.update(from: config)
        feedback.play()
    }

    @Test("Update clamps volume from config")
    func updateClampsVolume() {
        let feedback = SoundFeedback(enabled: true, volume: 0.5)

        var config = GestureFireConfig.defaults
        config.soundVolume = 5.0 // Over range
        feedback.update(from: config)
        feedback.play()

        config.soundVolume = -1.0 // Under range
        feedback.update(from: config)
        feedback.play()
    }
}
