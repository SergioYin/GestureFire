import GestureFireEngine
import GestureFireTypes
import SwiftUI

struct AdvancedSettingsView: View {
    let coordinator: AppCoordinator
    @State private var showResetConfirmation = false

    private var sensitivity: SensitivityConfig {
        coordinator.configStore.config.sensitivity
    }

    var body: some View {
        Form {
            Section("TipTap Parameters") {
                parameterRow(
                    .holdThresholdMs,
                    label: "Hold Duration",
                    description: "How long a finger must be held before a tap is recognized",
                    unit: "ms"
                )
                parameterRow(
                    .tapMaxDurationMs,
                    label: "Tap Speed",
                    description: "Maximum time for the second finger's tap to count",
                    unit: "ms"
                )
                parameterRow(
                    .movementTolerance,
                    label: "Movement Sensitivity",
                    description: "How much finger movement is allowed during a tap",
                    unit: ""
                )
                parameterRow(
                    .debounceCooldownMs,
                    label: "Repeat Delay",
                    description: "Minimum wait between consecutive gesture recognitions",
                    unit: "ms"
                )
                // directionAngleTolerance intentionally hidden — not wired into recognizer.
                // Will be exposed in Phase 3 when direction logic is implemented.
            }

            Section {
                Button("Reset to Defaults") {
                    showResetConfirmation = true
                }
                .confirmationDialog(
                    "Reset all parameters to defaults?",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) {
                        coordinator.configStore.update { config in
                            config.sensitivity = .defaults
                        }
                        Task { await coordinator.reloadSensitivity() }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
    }

    @ViewBuilder
    private func parameterRow(
        _ param: SensitivityConfig.Parameter,
        label: String,
        description: String,
        unit: String
    ) -> some View {
        let bounds = ParameterBounds.bounds(for: param)
        let value = sensitivity.value(for: param)

        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(label) {
                HStack {
                    Slider(
                        value: Binding(
                            get: { value },
                            set: { newValue in
                                coordinator.configStore.update { config in
                                    config.sensitivity = config.sensitivity.withValue(newValue, for: param)
                                }
                                Task { await coordinator.reloadSensitivity() }
                            }
                        ),
                        in: bounds.min...bounds.max
                    )
                    Text("\(value, specifier: "%.1f")\(unit)")
                        .frame(width: 80, alignment: .trailing)
                        .monospacedDigit()
                }
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
