import Foundation
import GestureFireTypes

/// Actor that owns all recognizers and processes touch frames serially.
/// Receives config snapshots (value types) — never callbacks to MainActor.
public actor RecognitionLoop {
    private var recognizers: [any GestureRecognizer]
    private var currentSensitivity: SensitivityConfig

    public init(sensitivity: SensitivityConfig) {
        self.currentSensitivity = sensitivity
        self.recognizers = [
            TipTapRecognizer(sensitivity: sensitivity),
        ]
    }

    /// Process a single touch frame through all recognizers.
    /// Returns the first recognized gesture, or an empty result with all rejections.
    public func processFrame(_ frame: TouchFrame) -> EngineResult {
        var allRejections: [RejectionReason] = []

        for index in recognizers.indices {
            let result = recognizers[index].processFrame(frame)
            if let gesture = result.gesture {
                return EngineResult(gesture: gesture, allRejections: [])
            }
            allRejections.append(contentsOf: result.rejections)
        }

        return EngineResult(gesture: nil, allRejections: allRejections)
    }

    /// Update sensitivity for all recognizers. Called when config changes.
    public func updateSensitivity(_ sensitivity: SensitivityConfig) {
        currentSensitivity = sensitivity
        recognizers = [
            TipTapRecognizer(sensitivity: sensitivity),
        ]
    }

    /// Replay a sequence of frames. Resets recognizer state before replay.
    /// Returns one EngineResult per frame — deterministic for the same input.
    public func replay(frames: [TouchFrame]) -> [EngineResult] {
        // Reset to clean state
        recognizers = [
            TipTapRecognizer(sensitivity: currentSensitivity),
        ]
        return frames.map { processFrame($0) }
    }
}
