import Foundation
import GestureFireTypes

/// Actor that owns all recognizers and processes touch frames serially.
/// Receives config snapshots (value types) — never callbacks to MainActor.
public actor RecognitionLoop {
    private var recognizers: [any GestureRecognizer]

    public init(sensitivity: SensitivityConfig) {
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
        recognizers = [
            TipTapRecognizer(sensitivity: sensitivity),
        ]
    }
}
