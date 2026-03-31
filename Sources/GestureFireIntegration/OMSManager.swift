import Foundation
import GestureFireTypes
import OpenMultitouchSupport

/// Wraps OMS's OMSManager to produce TouchFrame values.
/// The only component that directly uses OpenMultitouchSupport APIs.
public final class OMSTouchSource: @unchecked Sendable {
    private let manager = OMSManager.shared
    private var task: Task<Void, Never>?
    private let onFrame: @Sendable (TouchFrame) -> Void
    public private(set) var hasReceivedFrame = false

    public init(onFrame: @escaping @Sendable (TouchFrame) -> Void) {
        self.onFrame = onFrame
    }

    public func start() {
        guard manager.startListening() else { return }
        task = Task { [weak self, manager] in
            for await touchData in manager.touchDataStream {
                guard let self else { return }
                self.hasReceivedFrame = true
                let frame = TouchFrameAdapter.convert(touchData)
                self.onFrame(frame)
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        _ = manager.stopListening()
    }
}
