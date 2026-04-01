import Foundation
import Testing
@testable import GestureFireTypes

@Suite("TouchPoint Codable")
struct TouchPointCodableTests {
    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("TouchPoint round-trips through JSON")
    func touchPointRoundTrip() throws {
        let point = TouchPoint(
            id: 42,
            position: SIMD2(0.3, 0.7),
            state: .touching,
            timestamp: Date(timeIntervalSinceReferenceDate: 1000)
        )
        let data = try encoder.encode(point)
        let decoded = try decoder.decode(TouchPoint.self, from: data)
        #expect(decoded.id == point.id)
        #expect(decoded.position.x == point.position.x)
        #expect(decoded.position.y == point.position.y)
        #expect(decoded.state == point.state)
        #expect(decoded.timestamp == point.timestamp)
    }

    @Test("TouchFrame round-trips through JSON")
    func touchFrameRoundTrip() throws {
        let t = Date(timeIntervalSinceReferenceDate: 500)
        let frame = TouchFrame(points: [
            TouchPoint(id: 1, position: SIMD2(0.1, 0.2), state: .making, timestamp: t),
            TouchPoint(id: 2, position: SIMD2(0.8, 0.9), state: .touching, timestamp: t),
        ], timestamp: t)
        let data = try encoder.encode(frame)
        let decoded = try decoder.decode(TouchFrame.self, from: data)
        #expect(decoded.points.count == 2)
        #expect(decoded.points[0].id == 1)
        #expect(decoded.points[1].position.x == 0.8)
        #expect(decoded.timestamp == t)
    }

    @Test("Empty TouchFrame round-trips")
    func emptyFrame() throws {
        let t = Date(timeIntervalSinceReferenceDate: 0)
        let frame = TouchFrame(points: [], timestamp: t)
        let data = try encoder.encode(frame)
        let decoded = try decoder.decode(TouchFrame.self, from: data)
        #expect(decoded.points.isEmpty)
    }

    @Test("SIMD2 position encodes as array [x, y]")
    func simd2EncodesAsArray() throws {
        let point = TouchPoint(
            id: 1,
            position: SIMD2(0.5, 0.75),
            state: .hovering,
            timestamp: Date(timeIntervalSinceReferenceDate: 0)
        )
        let data = try encoder.encode(point)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let pos = json["position"] as! [Double]
        #expect(pos.count == 2)
        #expect(Float(pos[0]) == 0.5)
        #expect(Float(pos[1]) == 0.75)
    }
}
