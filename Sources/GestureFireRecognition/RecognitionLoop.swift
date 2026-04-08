import Foundation
import GestureFireTypes

/// Actor that owns all recognizers and processes touch frames serially.
/// Receives config snapshots (value types) — never callbacks to MainActor.
public actor RecognitionLoop {
    private var recognizers: [any GestureRecognizer]
    private var currentSensitivity: SensitivityConfig

    public init(sensitivity: SensitivityConfig) {
        self.currentSensitivity = sensitivity
        self.recognizers = Self.makeRecognizers(sensitivity: sensitivity)
    }

    /// Phase 3 fixed recognizer priority (highest first):
    /// 1. CornerTapRecognizer — most constrained (single finger + corner region)
    /// 2. MultiFingerTapRecognizer — ≥3 finger grouping, distinct from TipTap's 1+1
    /// 3. MultiFingerSwipeRecognizer — 3/4 finger motion, placed below tap so a
    ///    brief stationary 3-finger drop settles as a tap before motion evaluates
    /// 4. TipTapRecognizer — fallback 1+1 gesture, lowest priority
    ///
    /// Order is authoritative: when two recognizers report a gesture on the same
    /// frame, the earlier entry in this array wins.
    private static func makeRecognizers(sensitivity: SensitivityConfig) -> [any GestureRecognizer] {
        // Recognizers added incrementally across Phase 3 steps 3-5. Only TipTap
        // is implemented at this point; upcoming recognizers slot into the
        // positions reserved in the doc comment above.
        return [
            TipTapRecognizer(sensitivity: sensitivity),
        ]
    }

    /// Process a single touch frame through all recognizers.
    ///
    /// Every recognizer sees every frame so their state machines stay in sync
    /// with the frame timeline. When multiple recognizers report a gesture on
    /// the same frame, priority order (see `makeRecognizers`) decides the
    /// winner. Rejections from all recognizers are aggregated and returned.
    public func processFrame(_ frame: TouchFrame) -> EngineResult {
        var perRecognizer: [RecognitionResult] = []
        perRecognizer.reserveCapacity(recognizers.count)

        for index in recognizers.indices {
            perRecognizer.append(recognizers[index].processFrame(frame))
        }

        let allRejections = perRecognizer.flatMap { $0.rejections }
        for result in perRecognizer {
            if let gesture = result.gesture {
                return EngineResult(gesture: gesture, allRejections: allRejections)
            }
        }
        return EngineResult(gesture: nil, allRejections: allRejections)
    }

    /// Update sensitivity for all recognizers. Called when config changes.
    public func updateSensitivity(_ sensitivity: SensitivityConfig) {
        currentSensitivity = sensitivity
        recognizers = Self.makeRecognizers(sensitivity: sensitivity)
    }

    /// Replay a sequence of frames. Resets recognizer state before replay.
    /// Returns one EngineResult per frame — deterministic for the same input.
    public func replay(frames: [TouchFrame]) -> [EngineResult] {
        recognizers = Self.makeRecognizers(sensitivity: currentSensitivity)
        return frames.map { processFrame($0) }
    }
}
