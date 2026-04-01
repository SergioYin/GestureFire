import Foundation
import Testing
@testable import GestureFireEngine
import GestureFireTypes

@Suite("SampleRecorder")
struct SampleRecorderTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gesturefire-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Record and finish produces a valid .gesturesample file")
    @MainActor
    func recordAndFinish() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let recorder = SampleRecorder(sensitivity: .defaults, directory: dir)
        recorder.startRecording(for: .tipTapRight)
        #expect(recorder.isRecording)

        let t = Date(timeIntervalSinceReferenceDate: 0)
        recorder.recordFrame(TouchFrame(points: [], timestamp: t))
        recorder.recordFrame(TouchFrame(points: [], timestamp: t.addingTimeInterval(0.016)))
        #expect(recorder.frameCount == 2)

        let url = try recorder.finishRecording()
        #expect(url.pathExtension == "gesturesample")
        #expect(!recorder.isRecording)
        #expect(recorder.frameCount == 0)

        // Verify file is valid JSONL
        let data = try Data(contentsOf: url)
        let sample = try GestureSample.fromJSONL(data)
        #expect(sample.header.gestureType == .tipTapRight)
        #expect(sample.header.frameCount == 2)
        #expect(sample.frames.count == 2)
    }

    @Test("Cancel recording clears state without writing")
    @MainActor
    func cancelRecording() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let recorder = SampleRecorder(sensitivity: .defaults, directory: dir)
        recorder.startRecording(for: .tipTapLeft)
        recorder.recordFrame(TouchFrame(points: [], timestamp: Date()))
        recorder.cancelRecording()

        #expect(!recorder.isRecording)
        #expect(recorder.frameCount == 0)

        // No files written
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        #expect(files.isEmpty)
    }

    @Test("Recording frames while not recording is a no-op")
    @MainActor
    func recordWhileNotRecording() {
        let recorder = SampleRecorder(sensitivity: .defaults)
        recorder.recordFrame(TouchFrame(points: [], timestamp: Date()))
        #expect(recorder.frameCount == 0)
    }

    @Test("Finish without starting throws notRecording")
    @MainActor
    func finishWithoutStart() {
        let recorder = SampleRecorder(sensitivity: .defaults)
        #expect(throws: RecorderError.notRecording) {
            try recorder.finishRecording()
        }
    }

    @Test("Creates directory if missing")
    @MainActor
    func createsDirectory() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gesturefire-test-\(UUID().uuidString)")
            .appendingPathComponent("nested")
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }

        let recorder = SampleRecorder(sensitivity: .defaults, directory: dir)
        recorder.startRecording(for: .tipTapUp)
        recorder.recordFrame(TouchFrame(points: [], timestamp: Date()))
        let url = try recorder.finishRecording()
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
