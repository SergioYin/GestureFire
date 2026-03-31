import CoreGraphics
import GestureFireTypes

/// Single source of truth for virtual key codes (US keyboard layout).
/// v0.2 had two separate dictionaries; v1 consolidates into one place.
public enum KeyCodeMap {

    /// Look up the macOS virtual key code for a KeyShortcut.Key.
    public static func keyCode(for key: KeyShortcut.Key) -> CGKeyCode? {
        switch key {
        case .character(let c):
            characterCodes[c]
        case .function(let n):
            functionCodes[n]
        case .special(let s):
            specialCodes[s]
        }
    }

    /// Convert modifier set to CGEventFlags.
    public static func eventFlags(for modifiers: Set<KeyShortcut.Modifier>) -> CGEventFlags {
        var flags: CGEventFlags = []
        for modifier in modifiers {
            switch modifier {
            case .command: flags.insert(.maskCommand)
            case .control: flags.insert(.maskControl)
            case .option: flags.insert(.maskAlternate)
            case .shift: flags.insert(.maskShift)
            }
        }
        return flags
    }

    // MARK: - Key code tables

    private static let characterCodes: [Character: CGKeyCode] = [
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04,
        "g": 0x05, "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09,
        "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F,
        "y": 0x10, "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14,
        "4": 0x15, "6": 0x16, "5": 0x17, "=": 0x18, "9": 0x19,
        "7": 0x1A, "-": 0x1B, "8": 0x1C, "0": 0x1D, "]": 0x1E,
        "o": 0x1F, "u": 0x20, "[": 0x21, "i": 0x22, "p": 0x23,
        "l": 0x25, "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29,
        "\\": 0x2A, ",": 0x2B, "/": 0x2C, "n": 0x2D, "m": 0x2E,
        ".": 0x2F, "`": 0x32,
    ]

    private static let functionCodes: [Int: CGKeyCode] = [
        1: 0x7A, 2: 0x78, 3: 0x63, 4: 0x76,
        5: 0x60, 6: 0x61, 7: 0x62, 8: 0x64,
        9: 0x65, 10: 0x6D, 11: 0x67, 12: 0x6F,
        13: 0x69, 14: 0x6B, 15: 0x71, 16: 0x6A,
        17: 0x40, 18: 0x4F, 19: 0x50, 20: 0x5A,
    ]

    private static let specialCodes: [KeyShortcut.SpecialKey: CGKeyCode] = [
        .space: 0x31,
        .tab: 0x30,
        .returnKey: 0x24,
        .escape: 0x35,
        .delete: 0x33,
        .leftArrow: 0x7B,
        .rightArrow: 0x7C,
        .upArrow: 0x7E,
        .downArrow: 0x7D,
    ]
}
