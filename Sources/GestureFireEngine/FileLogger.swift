import Foundation
import GestureFireTypes

/// A single log entry for gesture recognition events.
public struct LogEntry: Sendable, Codable {
    public let timestamp: Date
    public let gesture: GestureType
    public let shortcut: String
    public let recognized: Bool

    public init(timestamp: Date, gesture: GestureType, shortcut: String, recognized: Bool) {
        self.timestamp = timestamp
        self.gesture = gesture
        self.shortcut = shortcut
        self.recognized = recognized
    }
}

/// JSONL file logger with daily rotation and configurable retention.
/// One file per day: `2026-03-31.jsonl`.
public struct FileLogger: Sendable {
    private let directory: URL
    private let retentionDays: Int
    private let dateFormatter: DateFormatter

    public init(directory: URL = AppConstants.logDirectory, retentionDays: Int = 30) {
        self.directory = directory
        self.retentionDays = retentionDays
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter = formatter
    }

    /// Append a log entry to today's file.
    public func log(_ entry: LogEntry) throws {
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        let line = String(data: data, encoding: .utf8)! + "\n"

        let file = fileURL(for: entry.timestamp)
        if FileManager.default.fileExists(atPath: file.path) {
            let handle = try FileHandle(forWritingTo: file)
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            handle.closeFile()
        } else {
            try line.write(to: file, atomically: true, encoding: .utf8)
        }
    }

    /// Read all entries from today's log.
    public func readToday() throws -> [LogEntry] {
        try readEntries(for: Date())
    }

    /// Read entries from a specific date's log file.
    public func readEntries(for date: Date) throws -> [LogEntry] {
        let file = fileURL(for: date)
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }

        let content = try String(contentsOf: file, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return content.split(separator: "\n").compactMap { line in
            try? decoder.decode(LogEntry.self, from: Data(line.utf8))
        }
    }

    /// Remove log files older than retention period.
    public func cleanup() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

        for file in files where file.pathExtension == "jsonl" {
            let name = file.deletingPathExtension().lastPathComponent
            if let fileDate = dateFormatter.date(from: name), fileDate < cutoff {
                try FileManager.default.removeItem(at: file)
            }
        }
    }

    private func fileURL(for date: Date) -> URL {
        let name = dateFormatter.string(from: date)
        return directory.appendingPathComponent("\(name).jsonl")
    }
}
