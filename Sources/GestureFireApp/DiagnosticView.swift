import GestureFireEngine
import SwiftUI

struct DiagnosticView: View {
    let coordinator: AppCoordinator
    @State private var results: [DiagnosticResult] = []
    @State private var isRunning = false
    @State private var layer2Confirmed: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diagnostics")
                .font(.title2)

            // Layer 1: Auto-detectable checks
            Section("Layer 1 — Auto Detection") {
                if results.isEmpty && !isRunning {
                    Text("Press Run to check system status")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                        HStack {
                            Image(systemName: result.status == .pass ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.status == .pass ? .green : .red)
                            Text(result.name)
                            Spacer()
                            if let fix = result.fixInstruction {
                                Text(fix)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // Layer 2: User confirmation
            Section("Layer 2 — User Confirmation") {
                Text("Did the shortcut work as expected?")
                HStack {
                    Button("Yes") { layer2Confirmed = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    Button("No") { layer2Confirmed = false }
                        .buttonStyle(.bordered)

                    if let confirmed = layer2Confirmed {
                        if confirmed {
                            Label("Everything working!", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            VStack(alignment: .leading) {
                                Text("Possible causes:")
                                    .font(.caption.bold())
                                Text("• Target app not in foreground")
                                    .font(.caption)
                                Text("• Shortcut intercepted by another tool")
                                    .font(.caption)
                                Text("• Invalid shortcut for the target app")
                                    .font(.caption)
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
            }

            Spacer()

            Button(isRunning ? "Running..." : "Run Diagnostics") {
                Task {
                    isRunning = true
                    results = await coordinator.runDiagnostics()
                    isRunning = false
                }
            }
            .disabled(isRunning)
        }
        .padding()
    }
}
