import Foundation
import GestureFireTypes
import OpenMultitouchSupport

/// Converts OMS touch data to our TouchFrame abstraction.
/// This is the ONLY file that imports OpenMultitouchSupport directly for conversion.
public enum TouchFrameAdapter {

    /// Convert raw OMS touch data array to a TouchFrame.
    public static func convert(_ touches: [OMSTouchData]) -> TouchFrame {
        let now = Date()
        let points = touches.map { touch -> TouchPoint in
            TouchPoint(
                id: touch.id,
                position: SIMD2(touch.position.x, touch.position.y),
                state: convertState(touch.state),
                timestamp: now
            )
        }
        return TouchFrame(points: points, timestamp: now)
    }

    private static func convertState(_ state: OMSState) -> TouchState {
        switch state {
        case .notTouching: .notTouching
        case .starting: .starting
        case .hovering: .hovering
        case .making: .making
        case .touching: .touching
        case .breaking: .breaking
        case .lingering: .lingering
        case .leaving: .leaving
        }
    }
}
