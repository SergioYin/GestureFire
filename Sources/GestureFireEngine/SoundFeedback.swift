import AppKit
import Foundation
import GestureFireTypes
import os

/// Fire-and-forget sound feedback for gesture recognition.
/// Plays a system sound asynchronously — never blocks the recognition pipeline.
@MainActor
public final class SoundFeedback {
    private var cachedSound: NSSound?
    private var isEnabled: Bool
    private var volume: Float

    private static let logger = Logger(subsystem: "com.gesturefire", category: "sound")

    public init(enabled: Bool = true, volume: Float = 0.5) {
        self.isEnabled = enabled
        self.volume = volume.clamped(to: 0...1)
        preloadSound()
    }

    /// Play the feedback sound if enabled. Non-blocking.
    public func play() {
        guard isEnabled, let sound = cachedSound else { return }
        // Stop any previous playback to avoid overlap
        sound.stop()
        sound.volume = volume
        sound.play() // NSSound.play() returns immediately (async playback)
    }

    /// Update settings from config. Call when config changes.
    public func update(from config: GestureFireConfig) {
        isEnabled = config.soundEnabled
        volume = config.soundVolume.clamped(to: 0...1)
    }

    private func preloadSound() {
        // Use system "Tink" sound — short, unobtrusive
        guard let sound = NSSound(named: "Tink") else {
            Self.logger.warning("Failed to load system sound 'Tink'")
            return
        }
        cachedSound = sound
    }
}

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
