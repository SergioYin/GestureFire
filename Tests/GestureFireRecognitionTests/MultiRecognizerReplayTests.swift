import Foundation
import Testing
@testable import GestureFireRecognition
import GestureFireTypes

/// Replay regression canary for Phase 3.
///
/// Loads committed `.gesturesample` fixtures via `Bundle.module` and asserts
/// the recognition output matches the fixture's declared `GestureType`. Every
/// Phase 3 step must keep this suite green: adding a new recognizer is never
/// an excuse for an older one to regress. If a prior fixture goes red, roll
/// back before continuing.
@Suite("Multi-recognizer replay regression")
struct MultiRecognizerReplayTests {

    // MARK: - Fixture loading

    private static func loadSample(subdir: String, name: String) throws -> GestureSample {
        // `.copy("Fixtures/samples")` places the whole directory into the
        // resource bundle, so entries are addressed as `samples/<subdir>/<name>`.
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "gesturesample",
            subdirectory: "samples/\(subdir)"
        ) else {
            Issue.record("Missing fixture: samples/\(subdir)/\(name).gesturesample")
            throw FixtureError.missing("\(subdir)/\(name)")
        }
        let data = try Data(contentsOf: url)
        return try GestureSample.fromJSONL(data)
    }

    private enum FixtureError: Error {
        case missing(String)
    }

    // MARK: - TipTap baseline

    @Test(
        "TipTap fixture replays to declared direction",
        arguments: [
            "tiptap-left",
            "tiptap-right",
            "tiptap-up",
            "tiptap-down",
        ]
    )
    func tipTapFixtureReplay(name: String) async throws {
        let sample = try Self.loadSample(subdir: "tiptap", name: name)
        let loop = RecognitionLoop(sensitivity: sample.header.sensitivity)
        let results = await loop.replay(frames: sample.frames)
        let recognized = results.compactMap(\.gesture)

        #expect(
            recognized == [sample.header.gestureType],
            "Fixture \(name) replayed as \(recognized), expected [\(sample.header.gestureType)]"
        )
    }

    // MARK: - CornerTap (Phase 3 Step 3)

    @Test(
        "CornerTap fixture replays to declared corner",
        arguments: [
            "cornertap-top-left",
            "cornertap-top-right",
            "cornertap-bottom-left",
            "cornertap-bottom-right",
        ]
    )
    func cornerTapFixtureReplay(name: String) async throws {
        let sample = try Self.loadSample(subdir: "cornertap", name: name)
        let loop = RecognitionLoop(sensitivity: sample.header.sensitivity)
        let results = await loop.replay(frames: sample.frames)
        let recognized = results.compactMap(\.gesture)

        #expect(
            recognized == [sample.header.gestureType],
            "Fixture \(name) replayed as \(recognized), expected [\(sample.header.gestureType)]"
        )
    }
}
