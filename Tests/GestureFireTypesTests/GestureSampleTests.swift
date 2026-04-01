import Foundation
import Testing
@testable import GestureFireTypes

@Suite("GestureSample")
struct GestureSampleTests {
    @Test("SampleHeader round-trips through JSON")
    func headerRoundTrip() throws {
        let header = SampleHeader(
            gestureType: .tipTapRight,
            sensitivity: .defaults,
            recordedAt: Date(timeIntervalSinceReferenceDate: 1000),
            frameCount: 5
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(header)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SampleHeader.self, from: data)
        #expect(decoded == header)
    }

    @Test("GestureSample JSONL round-trip")
    func jsonlRoundTrip() throws {
        let t = Date(timeIntervalSinceReferenceDate: 500)
        let frames = [
            TouchFrame(points: [
                TouchPoint(id: 1, position: SIMD2(0.3, 0.5), state: .touching, timestamp: t),
            ], timestamp: t),
            TouchFrame(points: [
                TouchPoint(id: 1, position: SIMD2(0.3, 0.5), state: .touching, timestamp: t),
                TouchPoint(id: 2, position: SIMD2(0.7, 0.5), state: .making, timestamp: t),
            ], timestamp: t),
        ]
        let sample = GestureSample(
            header: SampleHeader(
                gestureType: .tipTapRight,
                sensitivity: .defaults,
                recordedAt: t,
                frameCount: 2
            ),
            frames: frames
        )
        let data = try sample.toJSONL()
        let decoded = try GestureSample.fromJSONL(data)
        #expect(decoded.header == sample.header)
        #expect(decoded.frames.count == 2)
        #expect(decoded.frames[0].points.count == 1)
        #expect(decoded.frames[1].points.count == 2)
    }

    @Test("JSONL format has one JSON object per line")
    func jsonlLineFormat() throws {
        let t = Date(timeIntervalSinceReferenceDate: 0)
        let sample = GestureSample(
            header: SampleHeader(
                gestureType: .tipTapLeft,
                sensitivity: .defaults,
                recordedAt: t,
                frameCount: 1
            ),
            frames: [TouchFrame(points: [], timestamp: t)]
        )
        let data = try sample.toJSONL()
        let content = String(data: data, encoding: .utf8)!
        let lines = content.split(separator: "\n")
        #expect(lines.count == 2) // header + 1 frame
    }

    @Test("Empty file throws emptyFile error")
    func emptyFileError() {
        #expect(throws: SampleError.emptyFile) {
            try GestureSample.fromJSONL(Data())
        }
    }

    @Test("Frame count mismatch throws error")
    func frameCountMismatch() throws {
        let t = Date(timeIntervalSinceReferenceDate: 0)
        let sample = GestureSample(
            header: SampleHeader(
                gestureType: .tipTapUp,
                sensitivity: .defaults,
                recordedAt: t,
                frameCount: 5 // claim 5 but only provide 1
            ),
            frames: [TouchFrame(points: [], timestamp: t)]
        )
        let data = try sample.toJSONL()
        // Manually fix the header to claim wrong count
        // Actually the toJSONL uses the header as-is, so frameCount=5 but only 1 frame line
        #expect(throws: SampleError.frameCountMismatch(expected: 5, actual: 1)) {
            try GestureSample.fromJSONL(data)
        }
    }
}
