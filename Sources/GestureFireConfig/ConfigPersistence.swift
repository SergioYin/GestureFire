import Foundation
import GestureFireTypes

/// Protocol for config persistence. Enables mock in tests.
public protocol ConfigPersisting: Sendable {
    func load() throws -> GestureFireConfig?
    func save(_ config: GestureFireConfig) throws
}

/// File-based config persistence using JSON.
public struct FileConfigPersistence: ConfigPersisting, Sendable {
    private let fileURL: URL

    public init(fileURL: URL = AppConstants.configFile) {
        self.fileURL = fileURL
    }

    public func load() throws -> GestureFireConfig? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try ConfigMigration.migrate(from: data)
    }

    public func save(_ config: GestureFireConfig) throws {
        let dir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: .atomic)
    }
}
