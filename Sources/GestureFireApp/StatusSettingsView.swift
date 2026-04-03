import GestureFireEngine
import GestureFireTypes
import SwiftUI

/// Settings tab that replaces the standalone Diagnostics window.
/// Shows engine state, system checks, recent events, and troubleshooting.
struct StatusSettingsView: View {
    let coordinator: AppCoordinator
    @State private var diagnosticResults: [DiagnosticResult] = []
    @State private var isRunning = false
    @State private var layer2Confirmed: Bool?
    @State private var pollTask: Task<Void, Never>?

    private var allChecksPassed: Bool {
        !diagnosticResults.isEmpty && diagnosticResults.allSatisfy { $0.status == .pass }
    }

    private var hasAccessibilityFailure: Bool {
        diagnosticResults.contains { $0.name == "Accessibility Permission" && $0.status == .fail }
    }

    var body: some View {
        Form {
            engineStateSection
            systemChecksSection
            recentEventsSection
            if allChecksPassed {
                connectionTestSection
            }
        }
        .task {
            runChecks()
            startPollingIfNeeded()
        }
        .onDisappear {
            pollTask?.cancel()
        }
    }

    // MARK: - Engine State

    private var engineStateSection: some View {
        Section("Engine") {
            HStack {
                Image(systemName: coordinator.engineState.systemImage)
                    .foregroundStyle(engineStateColor)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coordinator.engineState.displayLabel)
                        .font(.headline)
                    Text(engineStateExplanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                engineActionButton
            }
        }
    }

    @ViewBuilder
    private var engineActionButton: some View {
        switch coordinator.engineState {
        case .disabled, .failed:
            Button("Enable") { coordinator.start() }
                .buttonStyle(.borderedProminent)
        case .needsPermission:
            Button("Grant & Retry") {
                coordinator.requestAccessibilityPermission()
            }
            .buttonStyle(.borderedProminent)
        case .starting:
            ProgressView()
                .controlSize(.small)
        case .running:
            Button("Disable") { coordinator.stop() }
                .buttonStyle(.bordered)
        }
    }

    private var engineStateColor: Color {
        switch coordinator.engineState {
        case .disabled: .secondary
        case .needsPermission: .orange
        case .starting: .blue
        case .running: .green
        case .failed: .red
        }
    }

    private var engineStateExplanation: String {
        switch coordinator.engineState {
        case .disabled:
            "Engine is off. Click Enable to start."
        case .needsPermission:
            "Accessibility permission is required. Grant it in System Settings."
        case .starting:
            "Waiting for first touch frame from trackpad..."
        case .running:
            "Engine is running and processing touch events."
        case .failed(let reason):
            reason
        }
    }

    // MARK: - System Checks

    private var systemChecksSection: some View {
        Section("System Checks") {
            if diagnosticResults.isEmpty && !isRunning {
                Text("Checking...")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(diagnosticResults.enumerated()), id: \.offset) { _, result in
                    HStack(alignment: .top) {
                        Image(systemName: result.status == .pass ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.status == .pass ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                            if let fix = result.fixInstruction {
                                Text(fix)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }

                if hasAccessibilityFailure {
                    Button("Open System Settings & Request Permission") {
                        coordinator.requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack {
                Button(isRunning ? "Checking..." : "Re-run Checks") {
                    layer2Confirmed = nil
                    runChecks()
                }
                .disabled(isRunning)

                if allChecksPassed {
                    Label("All Passed", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Recent Events

    private var recentEventsSection: some View {
        Section("Recent Events") {
            if coordinator.recentEvents.isEmpty {
                Text("No events yet. Enable the engine and perform a gesture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let events = Array(coordinator.recentEvents.suffix(5).reversed())
                ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: event.systemImage)
                            .foregroundStyle(eventColor(event))
                            .frame(width: 16)
                        Text(event.displayDescription)
                            .font(.caption)
                        Spacer()
                        Text(timeAgo(event.timestamp))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(index == 0 ? 1.0 : 0.7)
                }
            }
        }
    }

    // MARK: - Connection Test

    private var connectionTestSection: some View {
        Section("Connection Test") {
            if let event = coordinator.lastPipelineEvent {
                HStack(spacing: 6) {
                    Image(systemName: event.systemImage)
                        .foregroundStyle(eventColor(event))
                    Text(event.displayDescription)
                        .font(.callout)
                }
            }

            Text("Try a gesture now. Did the mapped shortcut trigger?")
                .font(.caption)

            HStack(spacing: 12) {
                Button("Yes, it worked") { layer2Confirmed = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                Button("No, nothing happened") { layer2Confirmed = false }
                    .buttonStyle(.bordered)
            }

            if let confirmed = layer2Confirmed {
                if confirmed {
                    Label("All systems working!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    DisclosureGroup("Troubleshooting") {
                        troubleshootingContent
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var troubleshootingContent: some View {
        let lastEvent = coordinator.lastPipelineEvent
        VStack(alignment: .leading, spacing: 4) {
            if lastEvent == nil {
                Text("No activity detected. Is the engine running?")
            }
            if case .rejected(let reason, _) = lastEvent {
                Text("Last gesture was rejected: \(reason)")
                Text("Try adjusting parameters in Advanced tab, or perform the gesture more deliberately")
            }
            if case .unmapped = lastEvent {
                Text("Gesture was recognized but has no shortcut mapped")
                Text("Go to Gestures tab and assign a shortcut")
            }
            if case .shortcutFailed = lastEvent {
                Text("Shortcut failed — check Accessibility permission")
            }
            Text("Target app must be in the foreground")
            Text("Shortcut may be intercepted by another tool (BetterTouchTool, Raycast, etc.)")
            Text("The shortcut key may not do anything in that app")
        }
        .font(.caption)
        .foregroundStyle(.orange)
    }

    // MARK: - Helpers

    private func eventColor(_ event: PipelineEvent) -> Color {
        switch event.semanticColor {
        case .green: .green
        case .blue: .blue
        case .orange: .orange
        case .yellow: .yellow
        case .red: .red
        case .secondary: .secondary
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 2 { return "now" }
        if seconds < 60 { return "\(seconds)s ago" }
        return "\(seconds / 60)m ago"
    }

    private func runChecks() {
        Task {
            isRunning = true
            diagnosticResults = await coordinator.runDiagnostics()
            isRunning = false
            if allChecksPassed {
                pollTask?.cancel()
            } else {
                startPollingIfNeeded()
            }
        }
    }

    private func startPollingIfNeeded() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                let newResults = await coordinator.runDiagnostics()
                await MainActor.run {
                    diagnosticResults = newResults
                    if allChecksPassed {
                        pollTask?.cancel()
                    }
                }
            }
        }
    }
}
