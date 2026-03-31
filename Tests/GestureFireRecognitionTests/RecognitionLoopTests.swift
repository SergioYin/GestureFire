import Foundation
import Testing
import GestureFireTypes
@testable import GestureFireRecognition

@Suite("RecognitionLoop")
struct RecognitionLoopTests {

    @Test("Processes TipTap sequence and returns gesture")
    func processesGesture() async {
        let loop = RecognitionLoop(sensitivity: .defaults)
        let frames = Fixtures.tipTapSequence(
            holdPos: SIMD2(0.3, 0.5),
            tapPos: SIMD2(0.7, 0.5)
        )

        var recognized: GestureType?
        for frame in frames {
            let result = await loop.processFrame(frame)
            if let gesture = result.gesture {
                recognized = gesture
            }
        }
        #expect(recognized == .tipTapRight)
    }

    @Test("Returns EngineResult with rejections when no gesture")
    func returnsRejections() async {
        let loop = RecognitionLoop(sensitivity: .defaults)
        // Single empty frame — no gesture
        let result = await loop.processFrame(
            Fixtures.frame([], at: Fixtures.time(0))
        )
        #expect(result.gesture == nil)
    }

    @Test("Updates sensitivity config")
    func updatesSensitivity() async {
        let loop = RecognitionLoop(sensitivity: .defaults)
        let newSensitivity = SensitivityConfig.defaults.withValue(100, for: .holdThresholdMs)
        await loop.updateSensitivity(newSensitivity)

        // With lower holdThreshold (100ms), a shorter hold should work
        let frames = Fixtures.tipTapSequence(
            holdStartMs: 0,
            tapAppearMs: 120, // hold = 120ms, enough for 100ms threshold
            tapDisappearMs: 200,
            postTapMs: 250
        )

        var recognized: GestureType?
        for frame in frames {
            let result = await loop.processFrame(frame)
            if let gesture = result.gesture {
                recognized = gesture
            }
        }
        #expect(recognized != nil, "Should recognize with lower holdThreshold")
    }

    @Test("Cooldown blocks rapid repeated gestures")
    func cooldownInLoop() async {
        let loop = RecognitionLoop(sensitivity: .defaults)

        // First gesture
        let frames1 = Fixtures.tipTapSequence(
            holdStartMs: 0,
            tapAppearMs: 250,
            tapDisappearMs: 350,
            postTapMs: 400
        )
        var count = 0
        for frame in frames1 {
            let result = await loop.processFrame(frame)
            if result.gesture != nil { count += 1 }
        }
        #expect(count == 1)

        // Second gesture too soon
        let frames2 = Fixtures.tipTapSequence(
            holdStartMs: 450,
            tapAppearMs: 700,
            tapDisappearMs: 800,
            postTapMs: 850
        )
        for frame in frames2 {
            let result = await loop.processFrame(frame)
            if result.gesture != nil { count += 1 }
        }
        #expect(count == 1, "Should still be 1 — second gesture blocked by cooldown")
    }
}
