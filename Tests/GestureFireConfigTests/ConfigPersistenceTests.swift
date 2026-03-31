import Foundation
import Testing
import GestureFireTypes
@testable import GestureFireConfig

@Suite("ConfigPersistence")
struct ConfigPersistenceTests {

    @Test("Save and load round-trip")
    func saveAndLoad() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file = tempDir.appendingPathComponent("config.json")
        let persistence = FileConfigPersistence(fileURL: file)

        var config = GestureFireConfig.defaults
        config.gestures["tipTapLeft"] = try KeyShortcut.parse("cmd+left")
        config.sensitivity = config.sensitivity.withValue(150, for: .holdThresholdMs)

        try persistence.save(config)
        let loaded = try #require(try persistence.load())

        #expect(loaded.version == 2)
        #expect(loaded.gestures["tipTapLeft"]?.stringValue == "cmd+left")
        #expect(loaded.sensitivity.holdThresholdMs == 150)
    }

    @Test("Load returns nil when file doesn't exist")
    func loadMissing() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("nonexistent.json")
        let persistence = FileConfigPersistence(fileURL: file)
        let config = try persistence.load()
        #expect(config == nil)
    }

    @Test("Creates parent directories on save")
    func createsDirectories() throws {
        let nested = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("sub")
            .appendingPathComponent("config.json")
        let persistence = FileConfigPersistence(fileURL: nested)
        defer { try? FileManager.default.removeItem(at: nested.deletingLastPathComponent().deletingLastPathComponent()) }

        try persistence.save(.defaults)
        let loaded = try persistence.load()
        #expect(loaded != nil)
    }
}
