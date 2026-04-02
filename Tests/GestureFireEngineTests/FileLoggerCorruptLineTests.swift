import Foundation
import Testing
@testable import GestureFireEngine
@testable import GestureFireTypes

@Suite("FileLogger corrupt line resilience")
struct FileLoggerCorruptLineTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gesturefire-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Valid JSONL lines are parsed correctly")
    func validLines() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let logger = FileLogger(directory: dir)
        let entry = LogEntry(timestamp: Date(), gesture: .tipTapLeft, shortcut: "cmd+left", recognized: true)
        try logger.log(entry)
        try logger.log(entry)

        let entries = try logger.readToday()
        #expect(entries.count == 2)
        #expect(entries[0].gesture == .tipTapLeft)
    }

    @Test("Corrupt lines are skipped, valid lines still returned")
    func corruptLinesSkipped() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let logger = FileLogger(directory: dir)

        // Write one valid entry
        let entry = LogEntry(timestamp: Date(), gesture: .tipTapRight, shortcut: "cmd+right", recognized: true)
        try logger.log(entry)

        // Manually append corrupt lines to today's file
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = formatter.string(from: Date()) + ".jsonl"
        let file = dir.appendingPathComponent(filename)

        let handle = try FileHandle(forWritingTo: file)
        handle.seekToEndOfFile()
        handle.write(Data("{corrupt json\n".utf8))
        handle.write(Data("\n".utf8)) // empty line
        handle.write(Data("not even json at all\n".utf8))
        handle.closeFile()

        // Write another valid entry after corrupt lines
        try logger.log(LogEntry(timestamp: Date(), gesture: .tipTapUp, shortcut: "cmd+up", recognized: true))

        let entries = try logger.readToday()
        // Should get 2 valid entries, 3 corrupt/empty lines skipped
        #expect(entries.count == 2)
        #expect(entries[0].gesture == .tipTapRight)
        #expect(entries[1].gesture == .tipTapUp)
    }

    @Test("Empty file returns empty array")
    func emptyFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = formatter.string(from: Date()) + ".jsonl"
        let file = dir.appendingPathComponent(filename)
        try "".write(to: file, atomically: true, encoding: .utf8)

        let logger = FileLogger(directory: dir)
        let entries = try logger.readToday()
        #expect(entries.isEmpty)
    }

    @Test("File with only corrupt lines returns empty array")
    func allCorrupt() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = formatter.string(from: Date()) + ".jsonl"
        let file = dir.appendingPathComponent(filename)
        try "not json\n{also bad}\nrandom\n".write(to: file, atomically: true, encoding: .utf8)

        let logger = FileLogger(directory: dir)
        let entries = try logger.readToday()
        #expect(entries.isEmpty)
    }

    @Test("Nonexistent date returns empty array")
    func nonexistentDate() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let logger = FileLogger(directory: dir)
        let farPast = Calendar.current.date(byAdding: .year, value: -10, to: Date())!
        let entries = try logger.readEntries(for: farPast)
        #expect(entries.isEmpty)
    }
}
