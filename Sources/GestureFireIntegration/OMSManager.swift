import Foundation
import GestureFireTypes
import OpenMultitouchSupport

/// Wraps OMS's OMSManager to produce TouchFrame values.
/// The only component that directly uses OpenMultitouchSupport APIs.
/// Actor-isolated to protect mutable state (task, hasReceivedFrame).
public actor OMSTouchSource {
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
                await self.markReceivedFrame()
                let frame = TouchFrameAdapter.convert(touchData)
                self.onFrame(frame)
            }
        }
    }

    private func markReceivedFrame() {
        hasReceivedFrame = true
    }

    public func stop() {
        task?.cancel()
        task = nil
        _ = manager.stopListening()
    }
}
