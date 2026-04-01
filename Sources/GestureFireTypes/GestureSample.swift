import Foundation

/// Header metadata for a .gesturesample file.
/// Line 1 of the JSONL file.
public struct SampleHeader: Sendable, Codable, Equatable {
    /// File format version (always 1 for now).
    public let version: Int
    /// The gesture type this sample demonstrates.
    public let gestureType: GestureType
    /// Sensitivity config at recording time.
    public let sensitivity: SensitivityConfig
    /// When the sample was recorded.
    public let recordedAt: Date
    /// Number of frames in the sample.
    public let frameCount: Int

    public init(
        version: Int = 1,
        gestureType: GestureType,
        sensitivity: SensitivityConfig,
        recordedAt: Date,
        frameCount: Int
    ) {
        self.version = version
        self.gestureType = gestureType
        self.sensitivity = sensitivity
        self.recordedAt = recordedAt
        self.frameCount = frameCount
    }
}

/// A complete gesture sample: header + frames.
/// The on-disk format is JSONL: line 1 = SampleHeader, lines 2+ = TouchFrame per line.
public struct GestureSample: Sendable, Equatable {
    public let header: SampleHeader
    public let frames: [TouchFrame]

    public init(header: SampleHeader, frames: [TouchFrame]) {
        self.header = header
        self.frames = frames
    }
}

// MARK: - JSONL Serialization

extension GestureSample {
    /// Encode to JSONL Data (line 1 = header, remaining lines = frames).
    public func toJSONL() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys

        var lines: [String] = []
        let headerData = try encoder.encode(header)
        lines.append(String(data: headerData, encoding: .utf8)!)

        for frame in frames {
            let frameData = try encoder.encode(frame)
            lines.append(String(data: frameData, encoding: .utf8)!)
        }

        let joined = lines.joined(separator: "\n") + "\n"
        return Data(joined.utf8)
    }

    /// Decode from JSONL Data.
    public static func fromJSONL(_ data: Data) throws -> GestureSample {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let content = String(data: data, encoding: .utf8) ?? ""
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        guard let firstLine = lines.first else {
            throw SampleError.emptyFile
        }

        let header = try decoder.decode(SampleHeader.self, from: Data(firstLine.utf8))
        let frames = try lines.dropFirst().map { line in
            try decoder.decode(TouchFrame.self, from: Data(line.utf8))
        }

        guard frames.count == header.frameCount else {
            throw SampleError.frameCountMismatch(expected: header.frameCount, actual: frames.count)
        }

        return GestureSample(header: header, frames: frames)
    }
}

public enum SampleError: Error, Equatable {
    case emptyFile
    case frameCountMismatch(expected: Int, actual: Int)
}
