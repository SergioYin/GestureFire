import Testing
import GestureFireTypes
@testable import GestureFireShortcuts

@Suite("KeyCodeMap")
struct KeyCodeMapTests {

    @Test("All lowercase letters have key codes")
    func allLetters() {
        for char in "abcdefghijklmnopqrstuvwxyz" {
            let code = KeyCodeMap.keyCode(for: .character(char))
            #expect(code != nil, "Missing key code for '\(char)'")
        }
    }

    @Test("All digits have key codes")
    func allDigits() {
        for char in "0123456789" {
            let code = KeyCodeMap.keyCode(for: .character(char))
            #expect(code != nil, "Missing key code for '\(char)'")
        }
    }

    @Test("Function keys F1-F12 have key codes")
    func functionKeys() {
        for n in 1...12 {
            let code = KeyCodeMap.keyCode(for: .function(n))
            #expect(code != nil, "Missing key code for F\(n)")
        }
    }

    @Test("Special keys have key codes", arguments: KeyShortcut.SpecialKey.allCases)
    func specialKeys(key: KeyShortcut.SpecialKey) {
        let code = KeyCodeMap.keyCode(for: .special(key))
        #expect(code != nil, "Missing key code for \(key)")
    }

    @Test("Known key codes match macOS virtual key codes")
    func knownCodes() {
        // Spot-check against Apple's key code reference
        #expect(KeyCodeMap.keyCode(for: .character("a")) == 0x00)
        #expect(KeyCodeMap.keyCode(for: .character("s")) == 0x01)
        #expect(KeyCodeMap.keyCode(for: .special(.returnKey)) == 0x24)
        #expect(KeyCodeMap.keyCode(for: .special(.space)) == 0x31)
        #expect(KeyCodeMap.keyCode(for: .special(.escape)) == 0x35)
        #expect(KeyCodeMap.keyCode(for: .function(1)) == 0x7A)
    }

    @Test("Modifier to CGEventFlags conversion")
    func modifierFlags() {
        let flags = KeyCodeMap.eventFlags(for: [.command, .shift])
        #expect(flags.contains(.maskCommand))
        #expect(flags.contains(.maskShift))
        #expect(!flags.contains(.maskControl))
        #expect(!flags.contains(.maskAlternate))
    }
}
