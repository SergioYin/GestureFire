import Foundation
import Testing
import GestureFireTypes
@testable import GestureFireRecognition

@Suite("MultiFingerSwipe happy path — 3 fingers")
struct MultiFingerSwipeThreeFingerHappyPathTests {

    @Test("3F swipe right")
    func threeRight() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 3,
            fromCentroid: SIMD2(0.3, 0.5),
            toCentroid: SIMD2(0.7, 0.5)
        )
        #expect(feedAllSwipe(&rec, frames: frames) == .multiFingerSwipe3Right)
    }

    @Test("3F swipe left")
    func threeLeft() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 3,
            fromCentroid: SIMD2(0.7, 0.5),
            toCentroid: SIMD2(0.3, 0.5)
        )
        #expect(feedAllSwipe(&rec, frames: frames) == .multiFingerSwipe3Left)
    }

    @Test("3F swipe up")
    func threeUp() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 3,
            fromCentroid: SIMD2(0.5, 0.3),
            toCentroid: SIMD2(0.5, 0.7)
        )
        #expect(feedAllSwipe(&rec, frames: frames) == .multiFingerSwipe3Up)
    }

    @Test("3F swipe down")
    func threeDown() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 3,
            fromCentroid: SIMD2(0.5, 0.7),
            toCentroid: SIMD2(0.5, 0.3)
        )
        #expect(feedAllSwipe(&rec, frames: frames) == .multiFingerSwipe3Down)
    }
}

@Suite("MultiFingerSwipe happy path — 4 fingers (symmetry with 3F)")
struct MultiFingerSwipeFourFingerHappyPathTests {

    @Test("4F swipe right")
    func fourRight() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 4,
            fromCentroid: SIMD2(0.3, 0.5),
            toCentroid: SIMD2(0.7, 0.5)
        )
        #expect(feedAllSwipe(&rec, frames: frames) == .multiFingerSwipe4Right)
    }

    @Test("4F swipe left")
    func fourLeft() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 4,
            fromCentroid: SIMD2(0.7, 0.5),
            toCentroid: SIMD2(0.3, 0.5)
        )
        #expect(feedAllSwipe(&rec, frames: frames) == .multiFingerSwipe4Left)
    }

    @Test("4F swipe up")
    func fourUp() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 4,
            fromCentroid: SIMD2(0.5, 0.3),
            toCentroid: SIMD2(0.5, 0.7)
        )
        #expect(feedAllSwipe(&rec, frames: frames) == .multiFingerSwipe4Up)
    }

    @Test("4F swipe down")
    func fourDown() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 4,
            fromCentroid: SIMD2(0.5, 0.7),
            toCentroid: SIMD2(0.5, 0.3)
        )
        #expect(feedAllSwipe(&rec, frames: frames) == .multiFingerSwipe4Down)
    }
}

@Suite("MultiFingerSwipe rejection / boundary")
struct MultiFingerSwipeRejectionTests {

    @Test("2-finger horizontal motion → not recognized (TipTap territory)")
    func twoFingerIgnored() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 2,
            fromCentroid: SIMD2(0.3, 0.5),
            toCentroid: SIMD2(0.7, 0.5)
        )
        #expect(feedAllSwipe(&rec, frames: frames) == nil)
    }

    @Test("5-finger horizontal motion → not recognized (out of {3,4})")
    func fiveFingerIgnored() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 5,
            fromCentroid: SIMD2(0.3, 0.5),
            toCentroid: SIMD2(0.7, 0.5)
        )
        #expect(feedAllSwipe(&rec, frames: frames) == nil)
    }

    @Test("3 fingers stationary (MultiFingerTap territory) → not recognized")
    func threeFingerStationary() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 3,
            fromCentroid: SIMD2(0.5, 0.5),
            toCentroid: SIMD2(0.5, 0.5) // zero motion
        )
        #expect(feedAllSwipe(&rec, frames: frames) == nil)
    }

    @Test("Centroid motion below swipeMinDistance → not recognized")
    func motionBelowThreshold() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        // displacement = 0.04 < default swipeMinDistance 0.08
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 3,
            fromCentroid: SIMD2(0.50, 0.5),
            toCentroid: SIMD2(0.54, 0.5)
        )
        #expect(feedAllSwipe(&rec, frames: frames) == nil)
    }

    @Test("45° diagonal motion → rejected directionAmbiguous")
    func diagonalAmbiguous() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 3,
            fromCentroid: SIMD2(0.3, 0.3),
            toCentroid: SIMD2(0.6, 0.6) // 45°
        )
        let outcome = runSwipeCollecting(&rec, frames: frames)
        #expect(outcome.gesture == nil)
        #expect(outcome.rejections.contains { $0.label == "directionAmbiguous" })
    }

    @Test("Swipe duration exceeds swipeMaxDurationMs → rejected swipeTooSlow")
    func swipeTooSlow() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        // default swipeMaxDurationMs = 800ms; stretch motion to 1200ms
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 3,
            fromCentroid: SIMD2(0.3, 0.5),
            toCentroid: SIMD2(0.7, 0.5),
            durationMs: 1200
        )
        let outcome = runSwipeCollecting(&rec, frames: frames)
        #expect(outcome.gesture == nil)
        #expect(outcome.rejections.contains { $0.label == "swipeTooSlow" })
    }

    @Test("Cluster breaks mid-motion (one finger diverges) → rejected clusterBroken")
    func clusterBroken() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        // Build a frame sequence where finger 1 and 2 move horizontally,
        // but finger 3 diverges vertically far enough to leave the cluster radius.
        var frames: [TouchFrame] = []
        let durationMs = 200
        let frameMs = 16
        var ms = 0
        while ms <= durationMs {
            let t = Fixtures.time(ms)
            let progress = Float(ms) / Float(durationMs)
            // Fingers 1, 2: moving from 0.3 → 0.7 horizontally
            let cx = 0.3 + 0.4 * progress
            let f1 = Fixtures.point(id: 1, x: cx - 0.02, y: 0.5, at: t)
            let f2 = Fixtures.point(id: 2, x: cx + 0.02, y: 0.5, at: t)
            // Finger 3: diverges vertically by up to 0.8 (well beyond swipeClusterTolerance 0.30)
            let f3 = Fixtures.point(id: 3, x: 0.5, y: 0.5 + 0.8 * progress, at: t)
            frames.append(Fixtures.frame([f1, f2, f3], at: t))
            ms += frameMs
        }
        // Lift
        for postMs in stride(from: durationMs + frameMs, through: durationMs + 200, by: frameMs) {
            frames.append(Fixtures.frame([], at: Fixtures.time(postMs)))
        }
        let outcome = runSwipeCollecting(&rec, frames: frames)
        #expect(outcome.gesture == nil)
        #expect(outcome.rejections.contains { $0.label == "clusterBroken" })
    }
}

@Suite("MultiFingerSwipe state transitions")
struct MultiFingerSwipeStateTests {

    @Test("Starts in idle state")
    func startsIdle() {
        let rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        #expect(rec.isIdle)
    }

    @Test("Enters cooldown after recognition")
    func entersCooldown() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerSwipeSequence(
            count: 3,
            fromCentroid: SIMD2(0.3, 0.5),
            toCentroid: SIMD2(0.7, 0.5)
        )
        _ = feedAllSwipe(&rec, frames: frames)
        #expect(rec.isCooldown)
    }

    @Test("Cooldown does not swallow a later legitimate swipe (after expiry)")
    func cooldownReleasesForNextSwipe() {
        var rec = MultiFingerSwipeRecognizer(sensitivity: .defaults)
        // First swipe completes by ~360ms; cooldown 500ms ends at ~860ms.
        let first = Fixtures.multiFingerSwipeSequence(
            count: 3,
            fromCentroid: SIMD2(0.3, 0.5),
            toCentroid: SIMD2(0.7, 0.5),
            motionStartMs: 0,
            durationMs: 160,
            postLiftMs: 100
        )
        let firstResult = feedAllSwipe(&rec, frames: first)
        #expect(firstResult == .multiFingerSwipe3Right)

        // Second swipe starts at 1000ms (well past cooldown)
        let second = Fixtures.multiFingerSwipeSequence(
            count: 3,
            fromCentroid: SIMD2(0.7, 0.5),
            toCentroid: SIMD2(0.3, 0.5),
            motionStartMs: 1000,
            durationMs: 160,
            postLiftMs: 200
        )
        let secondResult = feedAllSwipe(&rec, frames: second)
        #expect(secondResult == .multiFingerSwipe3Left,
                "Cooldown must not swallow a legitimate later swipe")
    }
}

// MARK: - Helpers

private func feedAllSwipe(_ rec: inout MultiFingerSwipeRecognizer, frames: [TouchFrame]) -> GestureType? {
    for frame in frames {
        let result = rec.processFrame(frame)
        if let gesture = result.gesture { return gesture }
    }
    return nil
}

private struct SwipeOutcome {
    let gesture: GestureType?
    let rejections: [RejectionReason]
}

private func runSwipeCollecting(_ rec: inout MultiFingerSwipeRecognizer, frames: [TouchFrame]) -> SwipeOutcome {
    var collected: [RejectionReason] = []
    for frame in frames {
        let result = rec.processFrame(frame)
        if let gesture = result.gesture {
            return SwipeOutcome(gesture: gesture, rejections: collected + result.rejections)
        }
        collected.append(contentsOf: result.rejections)
    }
    return SwipeOutcome(gesture: nil, rejections: collected)
}
