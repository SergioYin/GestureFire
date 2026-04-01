import Foundation
import Testing
@testable import GestureFireRecognition
import GestureFireTypes

@Suite("RecognitionLoop replay")
struct RecognitionLoopReplayTests {
    @Test("replay produces deterministic results across two calls")
    func replayDeterminism() async {
        let loop = RecognitionLoop(sensitivity: .defaults)
        let frames = Fixtures.tipTapSequence()

        let results1 = await loop.replay(frames: frames)
        let results2 = await loop.replay(frames: frames)

        // Both runs should produce the same recognition
        let recognized1 = results1.compactMap(\.gesture)
        let recognized2 = results2.compactMap(\.gesture)
        #expect(recognized1 == recognized2)
        #expect(recognized1.count == 1) // one TipTap recognized
    }

    @Test("replay resets recognizer state")
    func replayResetsState() async {
        let loop = RecognitionLoop(sensitivity: .defaults)

        // Feed partial frames to leave recognizer in tracking state
        let partial = Array(Fixtures.tipTapSequence().prefix(3))
        _ = await loop.replay(frames: partial)

        // Full replay should still work from clean state
        let full = Fixtures.tipTapSequence()
        let results = await loop.replay(frames: full)
        let recognized = results.compactMap(\.gesture)
        #expect(recognized.count == 1)
    }

    @Test("replay of empty frames returns empty results")
    func replayEmpty() async {
        let loop = RecognitionLoop(sensitivity: .defaults)
        let results = await loop.replay(frames: [])
        #expect(results.isEmpty)
    }
}
