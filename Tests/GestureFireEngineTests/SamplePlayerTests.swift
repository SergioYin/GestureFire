import Foundation
import Testing
@testable import GestureFireEngine
@testable import GestureFireRecognition
import GestureFireTypes

@Suite("SamplePlayer")
struct SamplePlayerTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gesturefire-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Create a synthetic TipTap sample using the same fixture pattern as recognition tests.
    private func makeTipTapSample() -> GestureSample {
        let baseTime = Date(timeIntervalSinceReferenceDate: 0)
        func time(_ ms: Int) -> Date { baseTime.addingTimeInterval(Double(ms) / 1000.0) }
        func point(_ id: Int32, _ x: Float, _ y: Float, _ t: Date) -> TouchPoint {
            TouchPoint(id: id, position: SIMD2(x, y), state: .touching, timestamp: t)
        }

        var frames: [TouchFrame] = []
        let holdId: Int32 = 1
        let tapId: Int32 = 2

        // Hold finger only (0-250ms)
        for ms in stride(from: 0, to: 250, by: 16) {
            frames.append(TouchFrame(points: [
                point(holdId, 0.3, 0.5, time(ms)),
            ], timestamp: time(ms)))
        }

        // Both fingers (250-350ms)
        for ms in stride(from: 250, to: 350, by: 16) {
            frames.append(TouchFrame(points: [
                point(holdId, 0.3, 0.5, time(ms)),
                point(tapId, 0.7, 0.5, time(ms)),
            ], timestamp: time(ms)))
        }

        // Hold finger only after tap lifts (350-400ms)
        for ms in stride(from: 350, through: 400, by: 16) {
            frames.append(TouchFrame(points: [
                point(holdId, 0.3, 0.5, time(ms)),
            ], timestamp: time(ms)))
        }

        return GestureSample(
            header: SampleHeader(
                gestureType: .tipTapRight,
                sensitivity: .defaults,
                recordedAt: baseTime,
                frameCount: frames.count
            ),
            frames: frames
        )
    }

    @Test("Load and replay a sample file")
    func loadAndReplay() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sample = makeTipTapSample()
        let fileURL = dir.appendingPathComponent("test.gesturesample")
        try sample.toJSONL().write(to: fileURL)

        let player = SamplePlayer()
        let loaded = try player.load(from: fileURL)
        #expect(loaded.header.gestureType == .tipTapRight)
        #expect(loaded.frames.count == sample.frames.count)

        let loop = RecognitionLoop(sensitivity: .defaults)
        let results = await player.replay(sample: loaded, through: loop)
        let recognized = results.compactMap(\.gesture)
        #expect(recognized.contains(.tipTapRight))
    }

    @Test("Replay produces same gesture as expected")
    func replayMatchesExpectedGesture() async throws {
        let sample = makeTipTapSample()
        let loop = RecognitionLoop(sensitivity: .defaults)
        let player = SamplePlayer()
        let results = await player.replay(sample: sample, through: loop)
        let recognized = results.compactMap(\.gesture)
        #expect(recognized == [.tipTapRight])
    }

    @Test("listSamples returns empty for missing directory")
    func listSamplesMissingDir() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString)")
        let files = try SamplePlayer.listSamples(in: dir)
        #expect(files.isEmpty)
    }

    @Test("listSamples finds .gesturesample files")
    func listSamplesFindsFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Create sample files
        try Data("test".utf8).write(to: dir.appendingPathComponent("a.gesturesample"))
        try Data("test".utf8).write(to: dir.appendingPathComponent("b.gesturesample"))
        try Data("test".utf8).write(to: dir.appendingPathComponent("c.txt")) // not a sample

        let files = try SamplePlayer.listSamples(in: dir)
        #expect(files.count == 2)
        #expect(files.allSatisfy { $0.pathExtension == "gesturesample" })
    }
}
