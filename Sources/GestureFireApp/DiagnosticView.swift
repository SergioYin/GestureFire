import GestureFireEngine
import GestureFireTypes
import SwiftUI

struct DiagnosticView: View {
    let coordinator: AppCoordinator
    @State private var diagnosticResults: [DiagnosticResult] = []
    @State private var isRunning = false
    @State private var layer2Confirmed: Bool?
    @State private var pollTask: Task<Void, Never>?

    private var allLayer1Passed: Bool {
        !diagnosticResults.isEmpty && diagnosticResults.allSatisfy { $0.status == .pass }
    }

    private var hasAccessibilityFailure: Bool {
        diagnosticResults.contains { $0.name == "Accessibility Permission" && $0.status == .fail }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                engineStateSection
                layer1Section
                pipelineActivitySection
                if allLayer1Passed {
                    layer2Section
                }
                controlsSection
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 500)
        .task {
            runChecks()
            startPollingIfNeeded()
        }
        .onDisappear {
            pollTask?.cancel()
        }
    }

    // MARK: - Header

    private var header: some View {
        Text("Diagnostics")
            .font(.title2)
    }

    // MARK: - Engine State

    private var engineStateSection: some View {
        GroupBox("Engine Status") {
            HStack {
                Image(systemName: coordinator.engineState.systemImage)
                    .foregroundColor(engineStateColor)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coordinator.engineState.displayLabel)
                        .font(.headline)
                    Text(engineStateExplanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if coordinator.engineState == .needsPermission {
                    Button("Grant & Retry") {
                        coordinator.requestAccessibilityPermission()
                        // Retry will be triggered by permission polling in AppCoordinator
                    }
                    .buttonStyle(.borderedProminent)
                }
                if case .failed = coordinator.engineState {
                    Button("Retry") { coordinator.retry() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 4)
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
            "Engine is off. Click Enable in the menu bar to start."
        case .needsPermission:
            "Accessibility permission is required. Grant it in System Settings, then this will auto-retry."
        case .starting:
            "Waiting for first touch frame from trackpad..."
        case .running:
            "Engine is running and processing touch events."
        case .failed(let reason):
            reason
        }
    }

    // MARK: - Layer 1

    private var layer1Section: some View {
        GroupBox("Layer 1 — System Checks") {
            VStack(alignment: .leading, spacing: 8) {
                if diagnosticResults.isEmpty && !isRunning {
                    Text("Checking...")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(diagnosticResults.enumerated()), id: \.offset) { _, result in
                        HStack(alignment: .top) {
                            Image(systemName: result.status == .pass ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.status == .pass ? .green : .red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name)
                                if let fix = result.fixInstruction {
                                    Text(fix)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }

                    if hasAccessibilityFailure {
                        Divider()
                        Button("Open System Settings & Request Permission") {
                            coordinator.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("This app's executable path:")
                                .font(.caption.bold())
                            Text(ProcessInfo.processInfo.arguments.first ?? "unknown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                            Text("Make sure this exact path is enabled in System Settings → Accessibility")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("After granting permission, status will update automatically.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Pipeline Activity

    private var pipelineActivitySection: some View {
        GroupBox("Pipeline Activity") {
            VStack(alignment: .leading, spacing: 6) {
                if coordinator.recentEvents.isEmpty {
                    Text("No events yet. Enable the engine and perform a gesture.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Show last 8 events, most recent first
                    let events = Array(coordinator.recentEvents.suffix(8).reversed())
                    ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: event.systemImage)
                                .foregroundColor(pipelineEventColor(event))
                                .frame(width: 16)
                            Text(event.displayDescription)
                                .font(.caption)
                            Spacer()
                            Text(timeAgo(event.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .opacity(index == 0 ? 1.0 : 0.7)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func pipelineEventColor(_ event: PipelineEvent) -> Color {
        switch event {
        case .frameReceived: .secondary
        case .recognized: .blue
        case .rejected: .orange
        case .unmapped: .yellow
        case .shortcutFired: .green
        case .shortcutFailed: .red
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 2 { return "now" }
        if seconds < 60 { return "\(seconds)s ago" }
        return "\(seconds / 60)m ago"
    }

    // MARK: - Layer 2

    private var layer2Section: some View {
        GroupBox("Layer 2 — User Confirmation") {
            VStack(alignment: .leading, spacing: 8) {
                // Show what the last gesture pipeline result was
                if let event = coordinator.lastPipelineEvent {
                    HStack(spacing: 6) {
                        Image(systemName: event.systemImage)
                            .foregroundColor(pipelineEventColor(event))
                        Text(event.displayDescription)
                            .font(.callout)
                    }
                    .padding(.vertical, 2)
                }

                Text("Try a gesture now. Did the mapped shortcut trigger?")
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
                            .foregroundColor(.green)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Troubleshooting:")
                                .font(.caption.bold())
                            troubleshootingItems
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var troubleshootingItems: some View {
        let lastEvent = coordinator.lastPipelineEvent
        VStack(alignment: .leading, spacing: 3) {
            // Context-aware troubleshooting based on pipeline state
            if lastEvent == nil {
                Text("- No pipeline activity detected. Is the engine running?")
            }
            if case .rejected(let reason, _) = lastEvent {
                Text("- Last gesture was rejected: \(reason)")
                Text("- Try adjusting sensitivity in Settings, or perform the gesture more deliberately")
            }
            if case .unmapped = lastEvent {
                Text("- Gesture was recognized but has no shortcut mapped")
                Text("- Go to Settings → Gestures and assign a shortcut")
            }
            if case .shortcutFailed = lastEvent {
                Text("- Shortcut fire failed — check Accessibility permission")
            }
            // Generic tips always shown
            Text("- Target app must be in the foreground")
            Text("- Shortcut may be intercepted by another tool (BetterTouchTool, Raycast, etc.)")
            Text("- The shortcut key may not do anything in that app")
            Text("- If no gesture mapped yet, check Settings → Gestures")
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack {
            Button(isRunning ? "Checking..." : "Re-run Diagnostics") {
                layer2Confirmed = nil
                runChecks()
            }
            .disabled(isRunning)
            .buttonStyle(.borderedProminent)

            if allLayer1Passed {
                Label("Layer 1 OK", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }

            Spacer()

            if coordinator.engineState == .disabled {
                Button("Enable Engine") { coordinator.start() }
                    .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Polling

    private func runChecks() {
        Task {
            isRunning = true
            diagnosticResults = await coordinator.runDiagnostics()
            isRunning = false
            if allLayer1Passed {
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
                    if allLayer1Passed {
                        pollTask?.cancel()
                    }
                }
            }
        }
    }
}
