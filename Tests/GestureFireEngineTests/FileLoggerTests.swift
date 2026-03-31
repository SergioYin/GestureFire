import Foundation
import Testing
import GestureFireTypes
@testable import GestureFireEngine

@Suite("FileLogger")
struct FileLoggerTests {

    @Test("Write and read log entries")
    func writeAndRead() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logger = FileLogger(directory: tempDir)
        let now = Date()
        let entry1 = LogEntry(
            timestamp: now,
            gesture: .tipTapLeft,
            shortcut: "cmd+left",
            recognized: true
        )
        let entry2 = LogEntry(
            timestamp: now.addingTimeInterval(1),
            gesture: .tipTapRight,
            shortcut: "cmd+right",
            recognized: true
        )

        try logger.log(entry1)
        try logger.log(entry2)

        let entries = try logger.readToday()
        #expect(entries.count == 2)
        #expect(entries[0].gesture == .tipTapLeft)
        #expect(entries[1].gesture == .tipTapRight)
    }

    @Test("JSONL format — one JSON object per line")
    func jsonlFormat() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logger = FileLogger(directory: tempDir)
        try logger.log(LogEntry(
            timestamp: Date(),
            gesture: .tipTapUp,
            shortcut: "cmd+up",
            recognized: true
        ))

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        #expect(files.count == 1)

        let content = try String(contentsOf: files[0], encoding: .utf8)
        let lines = content.split(separator: "\n")
        #expect(lines.count == 1)

        // Each line should be valid JSON
        let data = Data(lines[0].utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LogEntry.self, from: data)
        #expect(decoded.gesture == .tipTapUp)
    }

    @Test("Cleanup removes files older than retention period")
    func cleanup() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a fake old log file
        let oldDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let oldFile = tempDir.appendingPathComponent("\(formatter.string(from: oldDate)).jsonl")
        try "old data".write(to: oldFile, atomically: true, encoding: .utf8)

        // Create today's file
        let todayFile = tempDir.appendingPathComponent("\(formatter.string(from: Date())).jsonl")
        try "today data".write(to: todayFile, atomically: true, encoding: .utf8)

        let logger = FileLogger(directory: tempDir, retentionDays: 30)
        try logger.cleanup()

        let remaining = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        #expect(remaining.count == 1, "Old file should be removed, today's file kept")
    }
}
