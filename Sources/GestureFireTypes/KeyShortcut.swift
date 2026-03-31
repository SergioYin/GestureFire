import Foundation

/// Error thrown when parsing a shortcut string fails.
public enum ShortcutParseError: Error, Sendable, Equatable {
    case emptyInput
    case noKeyFound
    case unknownComponent(String)
}

/// A structured keyboard shortcut (e.g., Cmd+Shift+T).
/// Serialized as "cmd+shift+t" for v0.2 compatibility.
public struct KeyShortcut: Sendable, Hashable {
    public let modifiers: Set<Modifier>
    public let key: Key

    public init(modifiers: Set<Modifier>, key: Key) {
        self.modifiers = modifiers
        self.key = key
    }

    public enum Modifier: String, Sendable, CaseIterable, Codable, Hashable {
        case command
        case control
        case option
        case shift
    }

    public enum Key: Sendable, Hashable {
        case character(Character)
        case function(Int)
        case special(SpecialKey)
    }

    public enum SpecialKey: String, Sendable, CaseIterable, Codable, Hashable {
        case space
        case tab
        case returnKey = "return"
        case escape
        case delete
        case leftArrow = "left"
        case rightArrow = "right"
        case upArrow = "up"
        case downArrow = "down"
    }
}

// MARK: - Parsing

extension KeyShortcut {
    /// Parse a shortcut string like "cmd+shift+t" or "cmd+f5".
    public static func parse(_ string: String) throws(ShortcutParseError) -> KeyShortcut {
        let trimmed = string.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { throw .emptyInput }

        let components = trimmed.split(separator: "+").map(String.init)
        guard !components.isEmpty else { throw .emptyInput }

        var modifiers = Set<Modifier>()
        var keyComponent: String?

        for component in components {
            if let modifier = parseModifier(component) {
                modifiers.insert(modifier)
            } else if keyComponent == nil {
                keyComponent = component
            } else {
                throw .unknownComponent(component)
            }
        }

        guard let rawKey = keyComponent, !rawKey.isEmpty else {
            throw .noKeyFound
        }

        let key = try parseKey(rawKey)
        return KeyShortcut(modifiers: modifiers, key: key)
    }

    private static func parseModifier(_ string: String) -> Modifier? {
        switch string {
        case "cmd", "command": .command
        case "ctrl", "control": .control
        case "opt", "option", "alt": .option
        case "shift": .shift
        default: nil
        }
    }

    private static func parseKey(_ string: String) throws(ShortcutParseError) -> Key {
        // Function keys: f1-f20
        if string.hasPrefix("f"), string.count >= 2,
           let num = Int(string.dropFirst()), (1...20).contains(num)
        {
            return .function(num)
        }

        // Special keys
        if let special = SpecialKey(rawValue: string) {
            return .special(special)
        }

        // Single character
        if string.count == 1, let char = string.first {
            return .character(char)
        }

        throw .unknownComponent(string)
    }
}

// MARK: - String representation

extension KeyShortcut {
    /// Canonical string form, e.g. "cmd+shift+t". Modifier order is stable.
    public var stringValue: String {
        let modifierOrder: [Modifier] = [.command, .control, .option, .shift]
        let modParts = modifierOrder.filter { modifiers.contains($0) }.map { modifierString($0) }
        let keyPart = keyString(key)
        return (modParts + [keyPart]).joined(separator: "+")
    }

    private func modifierString(_ modifier: Modifier) -> String {
        switch modifier {
        case .command: "cmd"
        case .control: "ctrl"
        case .option: "option"
        case .shift: "shift"
        }
    }

    private func keyString(_ key: Key) -> String {
        switch key {
        case .character(let c): String(c)
        case .function(let n): "f\(n)"
        case .special(let s): s.rawValue
        }
    }
}

// MARK: - Codable (as string)

extension KeyShortcut: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        do {
            self = try KeyShortcut.parse(string)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid shortcut string: \(string)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

// MARK: - Equatable for Key

extension KeyShortcut.Key: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.character(let a), .character(let b)): a == b
        case (.function(let a), .function(let b)): a == b
        case (.special(let a), .special(let b)): a == b
        default: false
        }
    }
}

// MARK: - Codable for Key

extension KeyShortcut.Key: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "character":
            let str = try container.decode(String.self, forKey: .value)
            guard let char = str.first else {
                throw DecodingError.dataCorruptedError(
                    forKey: .value, in: container,
                    debugDescription: "Empty character"
                )
            }
            self = .character(char)
        case "function":
            let num = try container.decode(Int.self, forKey: .value)
            self = .function(num)
        case "special":
            let raw = try container.decode(String.self, forKey: .value)
            guard let key = KeyShortcut.SpecialKey(rawValue: raw) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .value, in: container,
                    debugDescription: "Unknown special key: \(raw)"
                )
            }
            self = .special(key)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown key type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .character(let c):
            try container.encode("character", forKey: .type)
            try container.encode(String(c), forKey: .value)
        case .function(let n):
            try container.encode("function", forKey: .type)
            try container.encode(n, forKey: .value)
        case .special(let s):
            try container.encode("special", forKey: .type)
            try container.encode(s.rawValue, forKey: .value)
        }
    }
}
