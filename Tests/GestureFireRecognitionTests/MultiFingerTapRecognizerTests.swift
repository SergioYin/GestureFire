import Foundation
import Testing
import GestureFireTypes
@testable import GestureFireRecognition

@Suite("MultiFingerTap happy path")
struct MultiFingerTapHappyPathTests {

    @Test("3 fingers tap together → multiFingerTap3")
    func threeFingerTap() {
        var recognizer = MultiFingerTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerTapSequence(
            positions: Fixtures.multiFingerCluster(count: 3)
        )
        let result = feedAllMulti(&recognizer, frames: frames)
        #expect(result == .multiFingerTap3)
    }

    @Test("4 fingers tap together → multiFingerTap4")
    func fourFingerTap() {
        var recognizer = MultiFingerTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerTapSequence(
            positions: Fixtures.multiFingerCluster(count: 4)
        )
        let result = feedAllMulti(&recognizer, frames: frames)
        #expect(result == .multiFingerTap4)
    }

    @Test("5 fingers tap together → multiFingerTap5")
    func fiveFingerTap() {
        var recognizer = MultiFingerTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerTapSequence(
            positions: Fixtures.multiFingerCluster(count: 5)
        )
        let result = feedAllMulti(&recognizer, frames: frames)
        #expect(result == .multiFingerTap5)
    }
}

@Suite("MultiFingerTap rejection / negative cases")
struct MultiFingerTapRejectionTests {

    @Test("2 fingers only → not recognized (TipTap territory)")
    func twoFingersIgnored() {
        var recognizer = MultiFingerTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerTapSequence(
            positions: Fixtures.multiFingerCluster(count: 2)
        )
        let result = feedAllMulti(&recognizer, frames: frames)
        #expect(result == nil)
    }

    @Test("Fingers spread beyond proximity threshold × 3 → rejected")
    func fingersTooSpread() {
        var recognizer = MultiFingerTapRecognizer(sensitivity: .defaults)
        // fingerProximityThreshold default = 0.15 → max spread = 0.45.
        // Place 3 fingers with pairwise distance well above 0.5.
        let positions: [SIMD2<Float>] = [
            SIMD2(0.1, 0.1),
            SIMD2(0.9, 0.1),
            SIMD2(0.5, 0.9),
        ]
        let frames = Fixtures.multiFingerTapSequence(positions: positions)
        let outcome = runAllMultiCollecting(&recognizer, frames: frames)
        #expect(outcome.gesture == nil)
        #expect(outcome.rejections.contains { $0.label == "fingersTooSpread" })
    }

    @Test("Tap held too long → rejected tapTooSlow")
    func tapTooSlow() {
        var recognizer = MultiFingerTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerTapSequence(
            positions: Fixtures.multiFingerCluster(count: 3),
            liftMs: 800 // > default multiFingerTapDurationMs (600)
        )
        let outcome = runAllMultiCollecting(&recognizer, frames: frames)
        #expect(outcome.gesture == nil)
        #expect(outcome.rejections.contains { $0.label == "tapTooSlow" })
    }

    @Test("One finger drifts beyond movementTolerance → rejected fingerMoved")
    func fingerMoved() {
        var recognizer = MultiFingerTapRecognizer(sensitivity: .defaults)
        var frames: [TouchFrame] = []
        let positions = Fixtures.multiFingerCluster(count: 3)
        // Stationary frames
        for i in 0..<5 {
            let t = Fixtures.time(i * 16)
            let pts = positions.enumerated().map { idx, pos in
                Fixtures.point(id: Int32(idx + 1), x: pos.x, y: pos.y, at: t)
            }
            frames.append(Fixtures.frame(pts, at: t))
        }
        // Drift finger 1 significantly
        for i in 5..<10 {
            let t = Fixtures.time(i * 16)
            let drift = Float(i - 4) * 0.025
            var pts: [TouchPoint] = [
                Fixtures.point(id: 1, x: positions[0].x + drift, y: positions[0].y, at: t),
            ]
            for idx in 1..<positions.count {
                pts.append(Fixtures.point(id: Int32(idx + 1), x: positions[idx].x, y: positions[idx].y, at: t))
            }
            frames.append(Fixtures.frame(pts, at: t))
        }
        let outcome = runAllMultiCollecting(&recognizer, frames: frames)
        #expect(outcome.gesture == nil)
        #expect(outcome.rejections.contains { $0.label == "fingerMoved" })
    }

    @Test("Staggered touchdown beyond tapGroupingWindow → not recognized")
    func staggeredTouchdown() {
        var recognizer = MultiFingerTapRecognizer(sensitivity: .defaults)
        // tapGroupingWindowMs default = 200
        // Finger 1 at t=0, fingers 2/3 at t=400 (well outside window).
        var frames: [TouchFrame] = []
        let positions = Fixtures.multiFingerCluster(count: 3)

        // Frames 0-380ms: finger 1 only
        for ms in stride(from: 0, through: 380, by: 16) {
            let t = Fixtures.time(ms)
            frames.append(Fixtures.frame([
                Fixtures.point(id: 1, x: positions[0].x, y: positions[0].y, at: t),
            ], at: t))
        }
        // Frames 400-500ms: all three fingers, then lift
        for ms in stride(from: 400, through: 500, by: 16) {
            let t = Fixtures.time(ms)
            let pts = positions.enumerated().map { idx, pos in
                Fixtures.point(id: Int32(idx + 1), x: pos.x, y: pos.y, at: t)
            }
            frames.append(Fixtures.frame(pts, at: t))
        }
        // Post-lift
        for ms in stride(from: 520, through: 700, by: 16) {
            frames.append(Fixtures.frame([], at: Fixtures.time(ms)))
        }

        let result = feedAllMulti(&recognizer, frames: frames)
        #expect(result == nil, "Touchdown spread over >200ms should not count as multi-finger tap")
    }
}

@Suite("MultiFingerTap state transitions")
struct MultiFingerTapStateTests {

    @Test("Starts in idle state")
    func startsIdle() {
        let recognizer = MultiFingerTapRecognizer(sensitivity: .defaults)
        #expect(recognizer.isIdle)
    }

    @Test("Enters cooldown after recognition")
    func entersCooldown() {
        var recognizer = MultiFingerTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.multiFingerTapSequence(
            positions: Fixtures.multiFingerCluster(count: 3)
        )
        _ = feedAllMulti(&recognizer, frames: frames)
        #expect(recognizer.isCooldown)
    }
}

// MARK: - Helpers

private func feedAllMulti(_ recognizer: inout MultiFingerTapRecognizer, frames: [TouchFrame]) -> GestureType? {
    for frame in frames {
        let result = recognizer.processFrame(frame)
        if let gesture = result.gesture {
            return gesture
        }
    }
    return nil
}

private struct MultiOutcome {
    let gesture: GestureType?
    let rejections: [RejectionReason]
}

private func runAllMultiCollecting(_ recognizer: inout MultiFingerTapRecognizer, frames: [TouchFrame]) -> MultiOutcome {
    var collected: [RejectionReason] = []
    for frame in frames {
        let result = recognizer.processFrame(frame)
        if let gesture = result.gesture {
            return MultiOutcome(gesture: gesture, rejections: collected + result.rejections)
        }
        collected.append(contentsOf: result.rejections)
    }
    return MultiOutcome(gesture: nil, rejections: collected)
}
