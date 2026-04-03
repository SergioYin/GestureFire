import GestureFireEngine
import GestureFireTypes
import SwiftUI

struct LogViewerView: View {
    let coordinator: AppCoordinator

    @State private var entries: [LogEntry] = []
    @State private var selectedDate = Date()
    @State private var filterGesture: GestureType?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar: date picker + gesture filter
            HStack {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.field)
                    .frame(width: 180)
                    .onChange(of: selectedDate) { loadEntries() }

                Picker("Filter", selection: $filterGesture) {
                    Text("All Gestures").tag(nil as GestureType?)
                    ForEach(GestureType.allCases, id: \.self) { gesture in
                        Text(gesture.displayName).tag(gesture as GestureType?)
                    }
                }
                .frame(width: 180)

                Spacer()

                Button {
                    loadEntries()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")

                Text("\(filteredEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)

            Divider()

            // Entry list
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if filteredEntries.isEmpty {
                ContentUnavailableView {
                    Label("No Entries", systemImage: "doc.text")
                } description: {
                    Text("No gesture events recorded for this date.")
                }
            } else {
                List(filteredEntries.indices.reversed(), id: \.self) { index in
                    LogEntryRow(entry: filteredEntries[index])
                }
                .listStyle(.inset)
            }
        }
        .onAppear { loadEntries() }
    }

    private var filteredEntries: [LogEntry] {
        guard let filter = filterGesture else { return entries }
        return entries.filter { $0.gesture == filter }
    }

    private func loadEntries() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let loaded = try coordinator.readLogEntries(for: selectedDate)
                entries = loaded
            } catch {
                errorMessage = error.localizedDescription
                entries = []
            }
            isLoading = false
        }
    }
}

// MARK: - Entry Row

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack {
            Image(systemName: entry.recognized ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(entry.recognized ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.gesture.displayName)
                    .font(.body)
                if !entry.shortcut.isEmpty {
                    Text(entry.shortcut)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(entry.timestamp, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, Spacing.xs)
    }
}
