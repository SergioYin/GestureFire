import Foundation
import Testing
@testable import GestureFireTypes

@Suite("PipelineEvent")
struct PipelineEventTests {
    private let now = Date()

    @Test("timestamp accessor returns correct time for all variants")
    func timestamps() {
        let events: [PipelineEvent] = [
            .frameReceived(fingerCount: 2, timestamp: now),
            .recognized(gesture: .tipTapLeft, timestamp: now),
            .rejected(reason: "too slow", timestamp: now),
            .unmapped(gesture: .tipTapRight, timestamp: now),
            .shortcutFired(gesture: .tipTapUp, shortcut: "cmd+t", timestamp: now),
            .shortcutFailed(gesture: .tipTapDown, shortcut: "cmd+w", timestamp: now),
        ]
        for event in events {
            #expect(event.timestamp == now)
        }
    }

    @Test("displayDescription is non-empty for all variants")
    func displayDescriptions() {
        let events: [PipelineEvent] = [
            .frameReceived(fingerCount: 2, timestamp: now),
            .recognized(gesture: .tipTapLeft, timestamp: now),
            .rejected(reason: "hold too short", timestamp: now),
            .unmapped(gesture: .tipTapRight, timestamp: now),
            .shortcutFired(gesture: .tipTapUp, shortcut: "cmd+t", timestamp: now),
            .shortcutFailed(gesture: .tipTapDown, shortcut: "cmd+w", timestamp: now),
        ]
        for event in events {
            #expect(!event.displayDescription.isEmpty)
        }
    }

    @Test("shortcutFired includes gesture and shortcut in description")
    func shortcutFiredDescription() {
        let event = PipelineEvent.shortcutFired(gesture: .tipTapLeft, shortcut: "cmd+shift+t", timestamp: now)
        #expect(event.displayDescription.contains("cmd+shift+t"))
        #expect(event.displayDescription.contains("TipTap Left"))
    }

    @Test("unmapped includes gesture name in description")
    func unmappedDescription() {
        let event = PipelineEvent.unmapped(gesture: .tipTapRight, timestamp: now)
        #expect(event.displayDescription.contains("TipTap Right"))
        #expect(event.displayDescription.contains("no shortcut"))
    }

    @Test("rejected includes reason in description")
    func rejectedDescription() {
        let event = PipelineEvent.rejected(reason: "finger moved too much", timestamp: now)
        #expect(event.displayDescription.contains("finger moved too much"))
    }

    @Test("systemImage and color are non-empty for all variants")
    func imageAndColor() {
        let events: [PipelineEvent] = [
            .frameReceived(fingerCount: 1, timestamp: now),
            .recognized(gesture: .tipTapLeft, timestamp: now),
            .rejected(reason: "x", timestamp: now),
            .unmapped(gesture: .tipTapRight, timestamp: now),
            .shortcutFired(gesture: .tipTapUp, shortcut: "cmd+t", timestamp: now),
            .shortcutFailed(gesture: .tipTapDown, shortcut: "cmd+w", timestamp: now),
        ]
        for event in events {
            #expect(!event.systemImage.isEmpty)
            #expect(!event.color.isEmpty)
        }
    }
}
