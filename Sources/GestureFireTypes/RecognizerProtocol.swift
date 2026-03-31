/// Protocol for gesture recognizers. Recognizers are value types (structs)
/// owned exclusively by `RecognitionLoop` actor.
public protocol GestureRecognizer: Sendable {
    /// Process a single touch frame and return a recognition result.
    /// Must use only `frame.timestamp` for timing — no system clock calls.
    mutating func processFrame(_ frame: TouchFrame) -> RecognitionResult
}
