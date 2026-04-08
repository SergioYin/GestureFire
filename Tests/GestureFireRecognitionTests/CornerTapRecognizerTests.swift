import Foundation
import Testing
import GestureFireTypes
@testable import GestureFireRecognition

@Suite("CornerTap happy path")
struct CornerTapHappyPathTests {

    @Test("Tap in top-left region → cornerTapTopLeft")
    func topLeft() {
        var recognizer = CornerTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.cornerTapSequence(position: SIMD2(0.1, 0.9))
        let result = feedAllCorner(&recognizer, frames: frames)
        #expect(result == .cornerTapTopLeft)
    }

    @Test("Tap in top-right region → cornerTapTopRight")
    func topRight() {
        var recognizer = CornerTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.cornerTapSequence(position: SIMD2(0.9, 0.9))
        let result = feedAllCorner(&recognizer, frames: frames)
        #expect(result == .cornerTapTopRight)
    }

    @Test("Tap in bottom-left region → cornerTapBottomLeft")
    func bottomLeft() {
        var recognizer = CornerTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.cornerTapSequence(position: SIMD2(0.1, 0.1))
        let result = feedAllCorner(&recognizer, frames: frames)
        #expect(result == .cornerTapBottomLeft)
    }

    @Test("Tap in bottom-right region → cornerTapBottomRight")
    func bottomRight() {
        var recognizer = CornerTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.cornerTapSequence(position: SIMD2(0.9, 0.1))
        let result = feedAllCorner(&recognizer, frames: frames)
        #expect(result == .cornerTapBottomRight)
    }
}

@Suite("CornerTap rejection / negative cases")
struct CornerTapRejectionTests {

    @Test("Tap in the center → not recognized")
    func centerTapIgnored() {
        var recognizer = CornerTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.cornerTapSequence(position: SIMD2(0.5, 0.5))
        let result = feedAllCorner(&recognizer, frames: frames)
        #expect(result == nil)
    }

    @Test("Tap just outside corner region → not recognized")
    func justOutsideCorner() {
        var recognizer = CornerTapRecognizer(sensitivity: .defaults)
        // cornerRegionSize default = 0.25 → corner condition is x < 0.25
        let frames = Fixtures.cornerTapSequence(position: SIMD2(0.30, 0.80))
        let result = feedAllCorner(&recognizer, frames: frames)
        #expect(result == nil)
    }

    @Test("Tap held too long → rejected tapTooSlow")
    func tooSlow() {
        var recognizer = CornerTapRecognizer(sensitivity: .defaults)
        // tapMaxDurationMs default = 300
        let frames = Fixtures.cornerTapSequence(
            position: SIMD2(0.1, 0.9),
            tapDurationMs: 500,
            postLiftMs: 200
        )
        let outcome = runAllCornerCollecting(&recognizer, frames: frames)
        #expect(outcome.gesture == nil)
        #expect(outcome.rejections.contains { $0.label == "tapTooSlow" })
    }

    @Test("Finger moves out of corner → rejected fingerMoved")
    func fingerMoves() {
        var recognizer = CornerTapRecognizer(sensitivity: .defaults)
        // Start in top-left corner, then drift significantly
        var frames: [TouchFrame] = []
        let id: Int32 = 1
        // Frame 0-3: stationary in corner
        for i in 0..<4 {
            let t = Fixtures.time(i * 16)
            frames.append(Fixtures.frame([
                Fixtures.point(id: id, x: 0.10, y: 0.90, at: t),
            ], at: t))
        }
        // Frame 4-8: drift outside movementTolerance (0.06 default)
        for i in 4..<9 {
            let t = Fixtures.time(i * 16)
            let drift = Float(i - 3) * 0.03
            frames.append(Fixtures.frame([
                Fixtures.point(id: id, x: 0.10 + drift, y: 0.90, at: t),
            ], at: t))
        }
        let outcome = runAllCornerCollecting(&recognizer, frames: frames)
        #expect(outcome.gesture == nil)
        #expect(outcome.rejections.contains { $0.label == "fingerMoved" })
    }

    @Test("Second finger appears → aborts without recognition")
    func secondFingerAborts() {
        var recognizer = CornerTapRecognizer(sensitivity: .defaults)
        let id1: Int32 = 1
        let id2: Int32 = 2
        var frames: [TouchFrame] = []
        // Finger 1 in corner
        for i in 0..<3 {
            let t = Fixtures.time(i * 16)
            frames.append(Fixtures.frame([
                Fixtures.point(id: id1, x: 0.1, y: 0.9, at: t),
            ], at: t))
        }
        // Second finger arrives
        for i in 3..<8 {
            let t = Fixtures.time(i * 16)
            frames.append(Fixtures.frame([
                Fixtures.point(id: id1, x: 0.1, y: 0.9, at: t),
                Fixtures.point(id: id2, x: 0.5, y: 0.5, at: t),
            ], at: t))
        }
        // Both lift
        frames.append(Fixtures.frame([], at: Fixtures.time(8 * 16)))
        let result = feedAllCorner(&recognizer, frames: frames)
        #expect(result == nil, "Second finger should abort corner tap")
    }
}

@Suite("CornerTap state transitions")
struct CornerTapStateTests {

    @Test("Starts in idle state")
    func startsIdle() {
        let recognizer = CornerTapRecognizer(sensitivity: .defaults)
        #expect(recognizer.isIdle)
    }

    @Test("Enters cooldown after recognition")
    func entersCooldown() {
        var recognizer = CornerTapRecognizer(sensitivity: .defaults)
        let frames = Fixtures.cornerTapSequence(position: SIMD2(0.1, 0.9))
        _ = feedAllCorner(&recognizer, frames: frames)
        #expect(recognizer.isCooldown)
    }

    @Test("Corner classification at default regionSize 0.25")
    func cornerClassification() {
        let r: Float = 0.25
        #expect(CornerTapRecognizer.corner(of: SIMD2(0.1, 0.9), regionSize: r) == .topLeft)
        #expect(CornerTapRecognizer.corner(of: SIMD2(0.9, 0.9), regionSize: r) == .topRight)
        #expect(CornerTapRecognizer.corner(of: SIMD2(0.1, 0.1), regionSize: r) == .bottomLeft)
        #expect(CornerTapRecognizer.corner(of: SIMD2(0.9, 0.1), regionSize: r) == .bottomRight)
        #expect(CornerTapRecognizer.corner(of: SIMD2(0.5, 0.5), regionSize: r) == nil)
        #expect(CornerTapRecognizer.corner(of: SIMD2(0.3, 0.9), regionSize: r) == nil)
    }
}

// MARK: - Helpers

private func feedAllCorner(_ recognizer: inout CornerTapRecognizer, frames: [TouchFrame]) -> GestureType? {
    for frame in frames {
        let result = recognizer.processFrame(frame)
        if let gesture = result.gesture {
            return gesture
        }
    }
    return nil
}

private struct CornerOutcome {
    let gesture: GestureType?
    let rejections: [RejectionReason]
}

private func runAllCornerCollecting(_ recognizer: inout CornerTapRecognizer, frames: [TouchFrame]) -> CornerOutcome {
    var collected: [RejectionReason] = []
    for frame in frames {
        let result = recognizer.processFrame(frame)
        if let gesture = result.gesture {
            return CornerOutcome(gesture: gesture, rejections: collected + result.rejections)
        }
        collected.append(contentsOf: result.rejections)
    }
    return CornerOutcome(gesture: nil, rejections: collected)
}
