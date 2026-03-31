import Foundation
import Testing
@testable import GestureFireTypes

@Suite("KeyShortcut parsing")
struct KeyShortcutParsingTests {

    @Test("Parse simple modifier + character")
    func parseSimple() throws {
        let shortcut = try KeyShortcut.parse("cmd+t")
        #expect(shortcut.modifiers == [.command])
        #expect(shortcut.key == .character("t"))
    }

    @Test("Parse multiple modifiers")
    func parseMultipleModifiers() throws {
        let shortcut = try KeyShortcut.parse("cmd+shift+n")
        #expect(shortcut.modifiers == [.command, .shift])
        #expect(shortcut.key == .character("n"))
    }

    @Test("Parse all four modifiers")
    func parseAllModifiers() throws {
        let shortcut = try KeyShortcut.parse("cmd+ctrl+option+shift+a")
        #expect(shortcut.modifiers == [.command, .control, .option, .shift])
        #expect(shortcut.key == .character("a"))
    }

    @Test("Parse function key")
    func parseFunctionKey() throws {
        let shortcut = try KeyShortcut.parse("cmd+f5")
        #expect(shortcut.modifiers == [.command])
        #expect(shortcut.key == .function(5))
    }

    @Test("Parse special keys", arguments: [
        ("cmd+space", KeyShortcut.SpecialKey.space),
        ("cmd+tab", KeyShortcut.SpecialKey.tab),
        ("cmd+return", KeyShortcut.SpecialKey.returnKey),
        ("cmd+escape", KeyShortcut.SpecialKey.escape),
        ("cmd+delete", KeyShortcut.SpecialKey.delete),
        ("cmd+left", KeyShortcut.SpecialKey.leftArrow),
        ("cmd+right", KeyShortcut.SpecialKey.rightArrow),
        ("cmd+up", KeyShortcut.SpecialKey.upArrow),
        ("cmd+down", KeyShortcut.SpecialKey.downArrow),
    ])
    func parseSpecialKeys(input: String, expected: KeyShortcut.SpecialKey) throws {
        let shortcut = try KeyShortcut.parse(input)
        #expect(shortcut.key == .special(expected))
    }

    @Test("Parse key without modifiers")
    func parseNoModifiers() throws {
        let shortcut = try KeyShortcut.parse("a")
        #expect(shortcut.modifiers.isEmpty)
        #expect(shortcut.key == .character("a"))
    }

    @Test("Empty string throws")
    func parseEmpty() {
        #expect(throws: ShortcutParseError.emptyInput) {
            try KeyShortcut.parse("")
        }
    }

    @Test("No key component throws")
    func parseNoKey() {
        #expect(throws: ShortcutParseError.noKeyFound) {
            try KeyShortcut.parse("cmd+shift+")
        }
    }

    @Test("Unknown modifier throws")
    func parseUnknownModifier() {
        #expect(throws: ShortcutParseError.self) {
            try KeyShortcut.parse("cmd+meta+a")
        }
    }

    @Test("Case insensitive parsing")
    func parseCaseInsensitive() throws {
        let shortcut = try KeyShortcut.parse("CMD+Shift+T")
        #expect(shortcut.modifiers == [.command, .shift])
        #expect(shortcut.key == .character("t"))
    }
}

@Suite("KeyShortcut serialization")
struct KeyShortcutSerializationTests {

    @Test("String representation matches parse format")
    func stringRepresentation() throws {
        let shortcut = try KeyShortcut.parse("cmd+shift+t")
        #expect(shortcut.stringValue == "cmd+shift+t")
    }

    @Test("Round-trip through Codable JSON")
    func codableRoundTrip() throws {
        let original = try KeyShortcut.parse("cmd+option+f3")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyShortcut.self, from: data)
        #expect(original == decoded)
    }

    @Test("Decodes from v0.2 format string")
    func decodesFromV02String() throws {
        // v0.2 stored shortcuts as plain strings like "cmd+shift+t"
        let json = #"{"keys":"cmd+shift+t"}"#
        struct V02Shortcut: Codable { let keys: String }
        let v02 = try JSONDecoder().decode(V02Shortcut.self, from: Data(json.utf8))
        let shortcut = try KeyShortcut.parse(v02.keys)
        let expected: Set<KeyShortcut.Modifier> = [.command, .shift]
        #expect(shortcut.modifiers == expected)
        #expect(shortcut.key == .character("t"))
    }
}

@Suite("KeyShortcut equality and hashing")
struct KeyShortcutEqualityTests {

    @Test("Same shortcut parsed differently is equal")
    func equalityIgnoresOrder() throws {
        let a = try KeyShortcut.parse("shift+cmd+t")
        let b = try KeyShortcut.parse("cmd+shift+t")
        #expect(a == b)
    }

    @Test("Different shortcuts are not equal")
    func inequality() throws {
        let a = try KeyShortcut.parse("cmd+t")
        let b = try KeyShortcut.parse("cmd+n")
        #expect(a != b)
    }
}
