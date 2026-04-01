import Foundation
import GestureFireTypes
import GestureFireRecognition

/// Loads .gesturesample files and replays them through RecognitionLoop.
/// Used for deterministic regression testing with real trackpad data.
public struct SamplePlayer: Sendable {
    public init() {}

    /// Load a sample from a .gesturesample file.
    public func load(from url: URL) throws -> GestureSample {
        let data = try Data(contentsOf: url)
        return try GestureSample.fromJSONL(data)
    }

    /// Replay all frames through the recognition loop. Returns one result per frame.
    public func replay(
        sample: GestureSample,
        through loop: RecognitionLoop
    ) async -> [EngineResult] {
        await loop.replay(frames: sample.frames)
    }

    /// List all .gesturesample files in a directory, sorted by modification date.
    public static func listSamples(
        in directory: URL = AppConstants.sampleDirectory
    ) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        return contents
            .filter { $0.pathExtension == "gesturesample" }
            .sorted { a, b in
                let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return aDate > bDate
            }
    }
}
