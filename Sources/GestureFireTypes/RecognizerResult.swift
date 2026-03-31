/// Reason a gesture was rejected, with debug-friendly details.
public struct RejectionReason: Sendable, Codable, Equatable {
    public let recognizer: String
    public let parameter: String
    public let threshold: Double
    public let actual: Double
    public let label: String

    public init(recognizer: String, parameter: String, threshold: Double, actual: Double, label: String) {
        self.recognizer = recognizer
        self.parameter = parameter
        self.threshold = threshold
        self.actual = actual
        self.label = label
    }
}

/// Result from a single recognizer's `processFrame`.
public struct RecognitionResult: Sendable {
    public let gesture: GestureType?
    public let rejections: [RejectionReason]

    public static let empty = RecognitionResult(gesture: nil, rejections: [])

    public static func recognized(_ gesture: GestureType) -> RecognitionResult {
        RecognitionResult(gesture: gesture, rejections: [])
    }

    public static func rejected(_ reasons: [RejectionReason]) -> RecognitionResult {
        RecognitionResult(gesture: nil, rejections: reasons)
    }

    public init(gesture: GestureType?, rejections: [RejectionReason]) {
        self.gesture = gesture
        self.rejections = rejections
    }
}

/// Aggregated result from the engine (all recognizers).
public struct EngineResult: Sendable {
    public let gesture: GestureType?
    public let allRejections: [RejectionReason]

    public init(gesture: GestureType?, allRejections: [RejectionReason]) {
        self.gesture = gesture
        self.allRejections = allRejections
    }
}
