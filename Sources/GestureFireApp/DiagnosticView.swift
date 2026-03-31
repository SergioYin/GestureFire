import GestureFireEngine
import SwiftUI

struct DiagnosticView: View {
    let coordinator: AppCoordinator
    @State private var results: [DiagnosticResult] = []
    @State private var isRunning = false
    @State private var layer2Confirmed: Bool?

    private var allLayer1Passed: Bool {
        !results.isEmpty && results.allSatisfy { $0.status == .pass }
    }

    private var hasAccessibilityFailure: Bool {
        results.contains { $0.name == "Accessibility Permission" && $0.status == .fail }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diagnostics")
                .font(.title2)

            // Layer 1: Auto-detectable checks
            GroupBox("Layer 1 — System Checks") {
                VStack(alignment: .leading, spacing: 8) {
                    if results.isEmpty && !isRunning {
                        Text("Click \"Run Diagnostics\" to check system status")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, result in
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
                            Button("Request Accessibility Permission") {
                                coordinator.requestAccessibilityPermission()
                                // Re-run after a short delay to let user respond
                                Task {
                                    try? await Task.sleep(for: .seconds(2))
                                    isRunning = true
                                    results = await coordinator.runDiagnostics()
                                    isRunning = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Layer 2: Only show when Layer 1 all passes
            if allLayer1Passed {
                GroupBox("Layer 2 — User Confirmation") {
                    VStack(alignment: .leading, spacing: 8) {
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
                                    Text("Possible causes:")
                                        .font(.caption.bold())
                                    Text("• Target app is not in the foreground")
                                    Text("• Shortcut is intercepted by another tool (BetterTouchTool, Raycast, etc.)")
                                    Text("• The shortcut key doesn't do anything in that app")
                                    Text("• No gesture is mapped yet — check Settings")
                                }
                                .font(.caption)
                                .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer()

            HStack {
                Button(isRunning ? "Running..." : "Run Diagnostics") {
                    layer2Confirmed = nil
                    Task {
                        isRunning = true
                        results = await coordinator.runDiagnostics()
                        isRunning = false
                    }
                }
                .disabled(isRunning)
                .buttonStyle(.borderedProminent)

                if allLayer1Passed {
                    Label("Layer 1 OK", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 320)
        .task {
            // Auto-run on open
            isRunning = true
            results = await coordinator.runDiagnostics()
            isRunning = false
        }
    }
}
