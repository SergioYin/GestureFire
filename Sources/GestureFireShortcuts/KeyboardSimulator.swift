import CoreGraphics
import Foundation
import GestureFireTypes
import os

/// Simulates keyboard shortcuts via CGEvent.
/// Nonisolated — CGEvent is thread-safe.
public enum KeyboardSimulator {
    private static let logger = Logger(subsystem: "com.gesturefire", category: "keyboard")

    /// Fire a keyboard shortcut. Returns true on success.
    @discardableResult
    public static func fire(_ shortcut: KeyShortcut) -> Bool {
        guard let keyCode = KeyCodeMap.keyCode(for: shortcut.key) else {
            logger.warning("No key code for: \(shortcut.stringValue)")
            return false
        }

        let flags = KeyCodeMap.eventFlags(for: shortcut.modifiers)
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            logger.error("Failed to create CGEvent for: \(shortcut.stringValue)")
            return false
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
