import Foundation
import Testing
import GestureFireTypes

/// Env-gated generator for checked-in replay fixtures.
///
/// Writes `.gesturesample` files to the source directory (not the build bundle)
/// so the committed assets stay in sync with the current `Fixtures.*Sequence(...)`
/// factories. To run:
///
///     GFIRE_GENERATE_FIXTURES=1 ./scripts/test.sh --filter FixtureGenerator
///
/// Without the env var set, every test in this suite returns immediately and
/// passes. This keeps the generator dormant on normal test runs.
@Suite("Fixture generator (env-gated)")
struct FixtureGenerator {
    private static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["GFIRE_GENERATE_FIXTURES"] == "1"
    }

    /// Source directory for replay fixtures. Resolved from `#filePath` so
    /// regeneration writes next to the committed files regardless of the
    /// current working directory.
    private static func fixtureDir(_ subdir: String, file: String = #filePath) -> URL {
        URL(fileURLWithPath: file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/samples/\(subdir)", isDirectory: true)
    }

    private static func write(_ sample: GestureSample, to dir: URL, name: String) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(name).gesturesample")
        let data = try sample.toJSONL()
        try data.write(to: url, options: .atomic)
    }

    // MARK: - TipTap

    @Test("Generate TipTap fixtures")
    func generateTipTap() throws {
        guard Self.isEnabled else { return }

        let dir = Self.fixtureDir("tiptap")
        let sensitivity = SensitivityConfig.defaults
        let recordedAt = Date(timeIntervalSinceReferenceDate: 0)

        // Each entry: (name, expected gesture, hold position, tap position)
        let variants: [(String, GestureType, SIMD2<Float>, SIMD2<Float>)] = [
            ("tiptap-left",  .tipTapLeft,  SIMD2(0.7, 0.5), SIMD2(0.3, 0.5)),
            ("tiptap-right", .tipTapRight, SIMD2(0.3, 0.5), SIMD2(0.7, 0.5)),
            ("tiptap-up",    .tipTapUp,    SIMD2(0.5, 0.3), SIMD2(0.5, 0.7)),
            ("tiptap-down",  .tipTapDown,  SIMD2(0.5, 0.7), SIMD2(0.5, 0.3)),
        ]

        for (name, gesture, holdPos, tapPos) in variants {
            let frames = Fixtures.tipTapSequence(holdPos: holdPos, tapPos: tapPos)
            let header = SampleHeader(
                gestureType: gesture,
                sensitivity: sensitivity,
                recordedAt: recordedAt,
                frameCount: frames.count
            )
            let sample = GestureSample(header: header, frames: frames)
            try Self.write(sample, to: dir, name: name)
        }
    }

    // MARK: - CornerTap

    @Test("Generate CornerTap fixtures")
    func generateCornerTap() throws {
        guard Self.isEnabled else { return }

        let dir = Self.fixtureDir("cornertap")
        let sensitivity = SensitivityConfig.defaults
        let recordedAt = Date(timeIntervalSinceReferenceDate: 0)

        // Each entry: (name, expected gesture, tap position inside the corner region)
        let variants: [(String, GestureType, SIMD2<Float>)] = [
            ("cornertap-top-left",     .cornerTapTopLeft,     SIMD2(0.10, 0.90)),
            ("cornertap-top-right",    .cornerTapTopRight,    SIMD2(0.90, 0.90)),
            ("cornertap-bottom-left",  .cornerTapBottomLeft,  SIMD2(0.10, 0.10)),
            ("cornertap-bottom-right", .cornerTapBottomRight, SIMD2(0.90, 0.10)),
        ]

        for (name, gesture, position) in variants {
            let frames = Fixtures.cornerTapSequence(position: position)
            let header = SampleHeader(
                gestureType: gesture,
                sensitivity: sensitivity,
                recordedAt: recordedAt,
                frameCount: frames.count
            )
            let sample = GestureSample(header: header, frames: frames)
            try Self.write(sample, to: dir, name: name)
        }
    }

    // MARK: - MultiFingerTap

    @Test("Generate MultiFingerTap fixtures")
    func generateMultiFingerTap() throws {
        guard Self.isEnabled else { return }

        let dir = Self.fixtureDir("multifingertap")
        let sensitivity = SensitivityConfig.defaults
        let recordedAt = Date(timeIntervalSinceReferenceDate: 0)

        // Each entry: (name, expected gesture, finger count)
        let variants: [(String, GestureType, Int)] = [
            ("multifingertap-3", .multiFingerTap3, 3),
            ("multifingertap-4", .multiFingerTap4, 4),
            ("multifingertap-5", .multiFingerTap5, 5),
        ]

        for (name, gesture, count) in variants {
            let positions = Fixtures.multiFingerCluster(count: count)
            let frames = Fixtures.multiFingerTapSequence(positions: positions)
            let header = SampleHeader(
                gestureType: gesture,
                sensitivity: sensitivity,
                recordedAt: recordedAt,
                frameCount: frames.count
            )
            let sample = GestureSample(header: header, frames: frames)
            try Self.write(sample, to: dir, name: name)
        }
    }

    // MARK: - MultiFingerSwipe

    @Test("Generate MultiFingerSwipe fixtures")
    func generateMultiFingerSwipe() throws {
        guard Self.isEnabled else { return }

        let dir = Self.fixtureDir("multifingerswipe")
        let sensitivity = SensitivityConfig.defaults
        let recordedAt = Date(timeIntervalSinceReferenceDate: 0)

        // Each entry: (name, gesture, count, fromCentroid, toCentroid)
        let variants: [(String, GestureType, Int, SIMD2<Float>, SIMD2<Float>)] = [
            ("multifingerswipe-3-right", .multiFingerSwipe3Right, 3, SIMD2(0.3, 0.5), SIMD2(0.7, 0.5)),
            ("multifingerswipe-3-left",  .multiFingerSwipe3Left,  3, SIMD2(0.7, 0.5), SIMD2(0.3, 0.5)),
            ("multifingerswipe-3-up",    .multiFingerSwipe3Up,    3, SIMD2(0.5, 0.3), SIMD2(0.5, 0.7)),
            ("multifingerswipe-3-down",  .multiFingerSwipe3Down,  3, SIMD2(0.5, 0.7), SIMD2(0.5, 0.3)),
            ("multifingerswipe-4-right", .multiFingerSwipe4Right, 4, SIMD2(0.3, 0.5), SIMD2(0.7, 0.5)),
            ("multifingerswipe-4-left",  .multiFingerSwipe4Left,  4, SIMD2(0.7, 0.5), SIMD2(0.3, 0.5)),
            ("multifingerswipe-4-up",    .multiFingerSwipe4Up,    4, SIMD2(0.5, 0.3), SIMD2(0.5, 0.7)),
            ("multifingerswipe-4-down",  .multiFingerSwipe4Down,  4, SIMD2(0.5, 0.7), SIMD2(0.5, 0.3)),
        ]

        for (name, gesture, count, from, to) in variants {
            let frames = Fixtures.multiFingerSwipeSequence(
                count: count,
                fromCentroid: from,
                toCentroid: to
            )
            let header = SampleHeader(
                gestureType: gesture,
                sensitivity: sensitivity,
                recordedAt: recordedAt,
                frameCount: frames.count
            )
            let sample = GestureSample(header: header, frames: frames)
            try Self.write(sample, to: dir, name: name)
        }
    }
}
