import Foundation
import Testing
import simd
@testable import GestureFireRecognition

@Suite("Geometry.nearestCardinal")
struct GeometryNearestCardinalTests {

    @Test("Pure +x vector → .right with 0°")
    func pureRight() {
        let result = Geometry.nearestCardinal(of: SIMD2<Float>(1.0, 0.0))
        #expect(result?.cardinal == .right)
        #expect((result?.angleDegrees ?? 999) < 0.001)
    }

    @Test("Pure -x vector → .left with 0°")
    func pureLeft() {
        let result = Geometry.nearestCardinal(of: SIMD2<Float>(-1.0, 0.0))
        #expect(result?.cardinal == .left)
        #expect((result?.angleDegrees ?? 999) < 0.001)
    }

    @Test("Pure +y vector → .up with 0° (OMS: +y is up)")
    func pureUp() {
        let result = Geometry.nearestCardinal(of: SIMD2<Float>(0.0, 1.0))
        #expect(result?.cardinal == .up)
        #expect((result?.angleDegrees ?? 999) < 0.001)
    }

    @Test("Pure -y vector → .down with 0°")
    func pureDown() {
        let result = Geometry.nearestCardinal(of: SIMD2<Float>(0.0, -1.0))
        #expect(result?.cardinal == .down)
        #expect((result?.angleDegrees ?? 999) < 0.001)
    }

    @Test("Zero vector → nil")
    func zeroVector() {
        let result = Geometry.nearestCardinal(of: SIMD2<Float>(0.0, 0.0))
        #expect(result == nil)
    }

    @Test("45° diagonal (dx=dy>0) → horizontal tiebreak .right with 45°")
    func fortyFiveTieRightUp() {
        let result = Geometry.nearestCardinal(of: SIMD2<Float>(0.3, 0.3))
        #expect(result?.cardinal == .right)
        #expect(abs((result?.angleDegrees ?? 0) - 45.0) < 0.001)
    }

    @Test("~26.57° off-axis horizontal (dx=0.4, dy=0.2) → .right")
    func nearAxialRight() {
        let result = Geometry.nearestCardinal(of: SIMD2<Float>(0.4, 0.2))
        #expect(result?.cardinal == .right)
        let expected = atan2(0.2, 0.4) * 180.0 / .pi
        #expect(abs((result?.angleDegrees ?? 0) - expected) < 0.001)
    }

    @Test("Vertical-dominant vector (dx=0.2, dy=0.4) → .up")
    func verticalDominantUp() {
        let result = Geometry.nearestCardinal(of: SIMD2<Float>(0.2, 0.4))
        #expect(result?.cardinal == .up)
        let expected = atan2(0.2, 0.4) * 180.0 / .pi
        #expect(abs((result?.angleDegrees ?? 0) - expected) < 0.001)
    }

    @Test("Negative-dominant vector (dx=-0.5, dy=-0.1) → .left")
    func negativeHorizontalDominant() {
        let result = Geometry.nearestCardinal(of: SIMD2<Float>(-0.5, -0.1))
        #expect(result?.cardinal == .left)
    }

    @Test("Negative vertical dominant (dx=0.1, dy=-0.5) → .down")
    func negativeVerticalDominant() {
        let result = Geometry.nearestCardinal(of: SIMD2<Float>(0.1, -0.5))
        #expect(result?.cardinal == .down)
    }
}
