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
            // MARK: Timing
            Section {
                parameterRow(
                    .holdThresholdMs,
                    label: "Hold Duration",
                    description: "How long a finger must be held before a TipTap is recognized",
                    unit: "ms"
                )
                parameterRow(
                    .tapMaxDurationMs,
                    label: "Tap Speed",
                    description: "Maximum time a tap can stay down before it stops counting",
                    unit: "ms"
                )
                parameterRow(
                    .tapGroupingWindowMs,
                    label: "Multi-Finger Timing Window",
                    description: "How close in time fingers must touch down to count as one group",
                    unit: "ms"
                )
                parameterRow(
                    .debounceCooldownMs,
                    label: "Repeat Delay",
                    description: "Minimum wait between consecutive gesture recognitions",
                    unit: "ms"
                )
            } header: {
                sectionHeader("Timing")
            }

            // MARK: Precision
            Section {
                parameterRow(
                    .movementTolerance,
                    label: "Movement Sensitivity",
                    description: "How much finger drift is allowed during a tap",
                    unit: ""
                )
                parameterRow(
                    .directionAngleTolerance,
                    label: "Direction Strictness",
                    description: "How close to a cardinal direction a swipe or TipTap must land",
                    unit: "°"
                )
                parameterRow(
                    .fingerProximityThreshold,
                    label: "Finger Spacing",
                    description: "How close together fingers must stay to count as a single cluster",
                    unit: ""
                )
            } header: {
                sectionHeader("Precision")
            }

            // MARK: Multi-Finger
            Section {
                parameterRow(
                    .multiFingerTapDurationMs,
                    label: "Tap Duration",
                    description: "How long a multi-finger tap can take from first finger down to all lifted",
                    unit: "ms"
                )
                parameterRow(
                    .multiFingerMovementTolerance,
                    label: "Movement Sensitivity",
                    description: "How much each finger can shift during a multi-finger tap",
                    unit: ""
                )
                parameterRow(
                    .multiFingerSpreadMax,
                    label: "Finger Spread",
                    description: "How far apart fingers can be in a multi-finger tap",
                    unit: ""
                )
                parameterRow(
                    .swipeClusterTolerance,
                    label: "Swipe Group Tightness",
                    description: "How closely fingers must stay together during a multi-finger swipe",
                    unit: ""
                )
            } header: {
                sectionHeader("Multi-Finger")
            }

            // MARK: Swipe
            Section {
                parameterRow(
                    .swipeMinDistance,
                    label: "Swipe Distance",
                    description: "Minimum travel for a swipe to register",
                    unit: ""
                )
                parameterRow(
                    .swipeMaxDurationMs,
                    label: "Swipe Time Limit",
                    description: "Maximum time a swipe can take before it is ignored",
                    unit: "ms"
                )
            } header: {
                sectionHeader("Swipe")
            }

            // MARK: Corner Tap
            Section {
                parameterRow(
                    .cornerRegionSize,
                    label: "Corner Region Size",
                    description: "How large each corner region is, as a fraction of the trackpad",
                    unit: ""
                )
            } header: {
                sectionHeader("Corner Tap")
            }

            // MARK: Palm Rejection
            Section {
                Toggle(
                    "Suppress gestures while typing",
                    isOn: Binding(
                        get: { coordinator.configStore.config.typingSuppressionEnabled },
                        set: { newValue in
                            coordinator.configStore.update { $0.typingSuppressionEnabled = newValue }
                            Task { await coordinator.reloadTypingSuppression() }
                        }
                    )
                )
                .accessibilityHint("Prevents accidental gestures when your palms rest on the trackpad while typing.")

                if coordinator.configStore.config.typingSuppressionEnabled {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text("Suppression Window")
                                .font(.body)
                            Spacer()
                            Text("\(Int(coordinator.configStore.config.typingSuppressionWindowMs)) ms")
                                .font(.title3.monospacedDigit())
                                .foregroundStyle(.primary)
                                .accessibilityHidden(true)
                        }
                        Slider(
                            value: Binding(
                                get: { coordinator.configStore.config.typingSuppressionWindowMs },
                                set: { newValue in
                                    coordinator.configStore.update { $0.typingSuppressionWindowMs = newValue }
                                }
                            ),
                            in: 100...2000,
                            step: 50
                        )
                        .tint(.accentColor)
                        .accessibilityLabel("Suppression Window")
                        .accessibilityValue("\(Int(coordinator.configStore.config.typingSuppressionWindowMs)) milliseconds")
                        .accessibilityHint("How long after a keystroke to block gesture recognition.")
                        Text("How long after a keystroke to block gestures. Lower values react faster; higher values give more protection.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, Spacing.xs)
                }
            } header: {
                sectionHeader("Palm Rejection")
            }

            // MARK: Reset
            Section {
                Button("Reset to Defaults") {
                    showResetConfirmation = true
                }
                .foregroundStyle(.secondary)
                .accessibilityHint("Restores every sensitivity parameter to its default value.")
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
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .accessibilityAddTraits(.isHeader)
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

        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(label)
                    .font(.body)
                Spacer()
                Text("\(value, specifier: "%.1f")\(unit)")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)
            }

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
            .tint(.accentColor)
            .accessibilityLabel(label)
            .accessibilityValue("\(Int(value))\(unit)")
            .accessibilityHint(description)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Spacing.xs)
    }
}
