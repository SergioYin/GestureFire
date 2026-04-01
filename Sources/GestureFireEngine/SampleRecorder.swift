import Foundation
import GestureFireTypes
import Observation
import os

/// Records TouchFrame sequences to .gesturesample JSONL files.
/// Used during calibration to capture real gesture samples.
@MainActor
@Observable
public final class SampleRecorder {
    public private(set) var isRecording = false
    public private(set) var frameCount = 0
    @ObservationIgnored private var frames: [TouchFrame] = []
    @ObservationIgnored private var currentGestureType: GestureType?
    @ObservationIgnored private let sensitivity: SensitivityConfig
    @ObservationIgnored private let directory: URL

    private static let logger = Logger(subsystem: "com.gesturefire", category: "sample-recorder")

    public init(sensitivity: SensitivityConfig, directory: URL = AppConstants.sampleDirectory) {
        self.sensitivity = sensitivity
        self.directory = directory
    }

    /// Begin recording frames for a specific gesture type.
    public func startRecording(for gestureType: GestureType) {
        frames.removeAll()
        frameCount = 0
        currentGestureType = gestureType
        isRecording = true
    }

    /// Append a frame to the current recording.
    public func recordFrame(_ frame: TouchFrame) {
        guard isRecording else { return }
        frames.append(frame)
        frameCount = frames.count
    }

    /// Finish recording and write the sample file. Returns the file URL.
    public func finishRecording() throws -> URL {
        guard isRecording, let gestureType = currentGestureType else {
            throw RecorderError.notRecording
        }

        let sample = GestureSample(
            header: SampleHeader(
                gestureType: gestureType,
                sensitivity: sensitivity,
                recordedAt: Date(),
                frameCount: frames.count
            ),
            frames: frames
        )

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let data = try sample.toJSONL()
        let fileName = "\(gestureType.rawValue)_\(ISO8601DateFormatter().string(from: Date())).gesturesample"
        let fileURL = directory.appendingPathComponent(fileName)
        try data.write(to: fileURL)

        Self.logger.info("Recorded \(self.frames.count) frames for \(gestureType.rawValue) → \(fileURL.lastPathComponent)")

        cleanup()
        return fileURL
    }

    /// Cancel recording without writing.
    public func cancelRecording() {
        cleanup()
    }

    private func cleanup() {
        isRecording = false
        frameCount = 0
        frames.removeAll()
        currentGestureType = nil
    }
}

public enum RecorderError: Error, Equatable {
    case notRecording
}
