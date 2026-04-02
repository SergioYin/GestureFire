import Foundation
import Testing
import GestureFireTypes
@testable import GestureFireRecognition

@Suite("TipTap happy path")
struct TipTapHappyPathTests {

    @Test("Hold left, tap right → tipTapRight")
    func tapRight() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.tipTapSequence(
            holdPos: SIMD2(0.3, 0.5),
            tapPos: SIMD2(0.7, 0.5)
        )
        let result = feedAll(&recognizer, frames: frames)
        #expect(result == .tipTapRight)
    }

    @Test("Hold right, tap left → tipTapLeft")
    func tapLeft() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.tipTapSequence(
            holdPos: SIMD2(0.7, 0.5),
            tapPos: SIMD2(0.3, 0.5)
        )
        let result = feedAll(&recognizer, frames: frames)
        #expect(result == .tipTapLeft)
    }

    @Test("Hold bottom, tap top → tipTapUp")
    func tapUp() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)
        // OMS: y increases upward in normalized coords
        let frames = Fixtures.tipTapSequence(
            holdPos: SIMD2(0.5, 0.3),
            tapPos: SIMD2(0.5, 0.7)
        )
        let result = feedAll(&recognizer, frames: frames)
        #expect(result == .tipTapUp)
    }

    @Test("Hold top, tap bottom → tipTapDown")
    func tapDown() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.tipTapSequence(
            holdPos: SIMD2(0.5, 0.7),
            tapPos: SIMD2(0.5, 0.3)
        )
        let result = feedAll(&recognizer, frames: frames)
        #expect(result == .tipTapDown)
    }
}

@Suite("TipTap rejection reasons")
struct TipTapRejectionTests {

    @Test("Tap too slow → rejected")
    func tapTooSlow() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)
        // Tap lasts 500ms (default tapMaxDurationMs is 300)
        let frames = Fixtures.tipTapSequence(
            tapAppearMs: 250,
            tapDisappearMs: 800,
            postTapMs: 850
        )
        let result = feedAll(&recognizer, frames: frames)
        #expect(result == nil, "Should not recognize when tap is too slow")
    }

    @Test("Hold too short → rejected")
    func holdTooShort() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)
        // Tap appears at 50ms and disappears at 100ms.
        // At 100ms the hold finger has only been present for 100ms (< 200ms threshold).
        let frames = Fixtures.tipTapSequence(
            holdStartMs: 0,
            tapAppearMs: 50,
            tapDisappearMs: 100,
            postTapMs: 150
        )
        let result = feedAll(&recognizer, frames: frames)
        #expect(result == nil, "Should not recognize when hold is too short")
    }

    @Test("Finger moved too much → rejected")
    func fingerMoved() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)
        let holdId: Int32 = 1
        let tapId: Int32 = 2

        // Hold finger that moves a lot
        var frames: [TouchFrame] = []
        for i in stride(from: 0, through: 300, by: 16) {
            let holdX: Float = 0.3 + Float(i) * 0.001 // drifts significantly
            frames.append(Fixtures.frame([
                Fixtures.point(id: holdId, x: holdX, y: 0.5, at: Fixtures.time(i)),
            ], at: Fixtures.time(i)))
        }
        // Add and remove tap finger
        for i in stride(from: 300, through: 380, by: 16) {
            frames.append(Fixtures.frame([
                Fixtures.point(id: holdId, x: 0.6, y: 0.5, at: Fixtures.time(i)),
                Fixtures.point(id: tapId, x: 0.8, y: 0.5, at: Fixtures.time(i)),
            ], at: Fixtures.time(i)))
        }
        frames.append(Fixtures.frame([
            Fixtures.point(id: holdId, x: 0.6, y: 0.5, at: Fixtures.time(400)),
        ], at: Fixtures.time(400)))

        let result = feedAll(&recognizer, frames: frames)
        #expect(result == nil, "Should reject when hold finger moves too much")
    }

    @Test("Cooldown blocks second recognition")
    func cooldownBlocks() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)

        // First TipTap
        let frames1 = Fixtures.tipTapSequence(
            holdStartMs: 0,
            tapAppearMs: 250,
            tapDisappearMs: 350,
            postTapMs: 400
        )
        let result1 = feedAll(&recognizer, frames: frames1)
        #expect(result1 != nil, "First gesture should be recognized")

        // Second TipTap too soon (within 500ms cooldown)
        let frames2 = Fixtures.tipTapSequence(
            holdStartMs: 450,
            tapAppearMs: 700,
            tapDisappearMs: 800,
            postTapMs: 850
        )
        let result2 = feedAll(&recognizer, frames: frames2)
        #expect(result2 == nil, "Second gesture within cooldown should be blocked")
    }

    @Test("Two-finger swipe (close fingers) → rejected")
    func twoFingerSwipeRejected() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)
        // Simulate two fingers close together (like a two-finger scroll)
        // Distance = 0.05, well below fingerProximityThreshold (0.15)
        let frames = Fixtures.tipTapSequence(
            holdPos: SIMD2(0.5, 0.5),
            tapPos: SIMD2(0.52, 0.53),
            holdStartMs: 0,
            tapAppearMs: 250,
            tapDisappearMs: 350,
            postTapMs: 400
        )
        let result = feedAll(&recognizer, frames: frames)
        #expect(result == nil, "Should reject when hold and tap fingers are too close (two-finger swipe)")
    }

    @Test("Fingers just above proximity threshold → recognized")
    func fingersAboveProximityThreshold() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)
        // Distance = ~0.2, above fingerProximityThreshold (0.15)
        let frames = Fixtures.tipTapSequence(
            holdPos: SIMD2(0.3, 0.5),
            tapPos: SIMD2(0.5, 0.5)
        )
        let result = feedAll(&recognizer, frames: frames)
        #expect(result != nil, "Should recognize when fingers are far enough apart")
    }

    @Test("After cooldown expires, recognition works again")
    func cooldownExpires() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)

        // First TipTap
        let frames1 = Fixtures.tipTapSequence(
            holdStartMs: 0,
            tapAppearMs: 250,
            tapDisappearMs: 350,
            postTapMs: 400
        )
        let result1 = feedAll(&recognizer, frames: frames1)
        #expect(result1 != nil)

        // Second TipTap after cooldown (>500ms later)
        let frames2 = Fixtures.tipTapSequence(
            holdStartMs: 1000,
            tapAppearMs: 1250,
            tapDisappearMs: 1350,
            postTapMs: 1400
        )
        let result2 = feedAll(&recognizer, frames: frames2)
        #expect(result2 != nil, "Should recognize after cooldown expires")
    }
}

@Suite("TipTap state transitions")
struct TipTapStateTests {

    @Test("Starts in idle state")
    func startsIdle() {
        let recognizer = TipTapRecognizer(sensitivity: .defaults)
        #expect(recognizer.isIdle)
    }

    @Test("Enters tracking after hold finger appears")
    func entersTracking() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)
        // Feed frames with a single stationary finger for >holdThresholdMs
        for i in stride(from: 0, through: 250, by: 16) {
            _ = recognizer.processFrame(Fixtures.frame([
                Fixtures.point(id: 1, x: 0.5, y: 0.5, at: Fixtures.time(i)),
            ], at: Fixtures.time(i)))
        }
        #expect(recognizer.isTracking)
    }

    @Test("Returns to idle after recognition + cooldown")
    func returnsToIdle() {
        var recognizer = TipTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.tipTapSequence(
            postTapMs: 400
        )
        _ = feedAll(&recognizer, frames: frames)

        // Feed empty frames past cooldown
        for i in stride(from: 1000, through: 1100, by: 16) {
            _ = recognizer.processFrame(Fixtures.frame([], at: Fixtures.time(i)))
        }
        #expect(recognizer.isIdle)
    }
}

// MARK: - Helpers

/// Feed all frames and return the first recognized gesture (or nil).
private func feedAll(_ recognizer: inout TipTapRecognizer, frames: [TouchFrame]) -> GestureType? {
    for frame in frames {
        let result = recognizer.processFrame(frame)
        if let gesture = result.gesture {
            return gesture
        }
    }
    return nil
}
