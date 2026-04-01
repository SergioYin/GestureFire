import GestureFireConfig
import GestureFireEngine
import GestureFireTypes
import SwiftUI

/// 4-step onboarding wizard.
struct OnboardingView: View {
    let coordinator: OnboardingCoordinator
    let appCoordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            StepIndicator(currentStep: coordinator.currentStep)
                .padding()

            Divider()

            // Step content
            Group {
                switch coordinator.currentStep {
                case .permission:
                    PermissionStepView(coordinator: coordinator)
                case .preset:
                    PresetStepView(coordinator: coordinator)
                case .practice:
                    PracticeStepView(coordinator: coordinator, appCoordinator: appCoordinator)
                case .confirm:
                    ConfirmStepView(coordinator: coordinator)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

            Divider()

            // Navigation buttons
            NavigationBar(coordinator: coordinator, appCoordinator: appCoordinator, dismiss: dismiss)
                .padding()
        }
        .frame(minWidth: 560, minHeight: 420)
        .onAppear {
            coordinator.checkPermission()
        }
    }
}

// MARK: - Step Indicator

private struct StepIndicator: View {
    let currentStep: OnboardingCoordinator.Step

    var body: some View {
        HStack(spacing: 16) {
            ForEach(OnboardingCoordinator.Step.allCases, id: \.rawValue) { step in
                HStack(spacing: 6) {
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(stepLabel(step))
                        .font(.caption)
                        .foregroundColor(step == currentStep ? .primary : .secondary)
                }
            }
        }
    }

    private func stepLabel(_ step: OnboardingCoordinator.Step) -> String {
        switch step {
        case .permission: "Permission"
        case .preset: "Preset"
        case .practice: "Practice"
        case .confirm: "Confirm"
        }
    }
}

// MARK: - Permission Step

private struct PermissionStepView: View {
    let coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Accessibility Permission")
                .font(.title2.bold())

            Text("GestureFire needs accessibility access to detect trackpad gestures and simulate keyboard shortcuts.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)

            switch coordinator.permissionState {
            case .unknown, .denied:
                Button("Grant Access") {
                    coordinator.requestPermission()
                }
                .controlSize(.large)

            case .requested:
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for permission...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Open System Settings → Privacy & Security → Accessibility")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

            case .granted:
                Label("Permission Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            }
        }
    }
}

// MARK: - Preset Step

private struct PresetStepView: View {
    let coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose a Preset")
                .font(.title2.bold())

            Text("Select a gesture-to-shortcut mapping to get started.")
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                ForEach(GesturePreset.allPresets) { preset in
                    PresetCard(
                        preset: preset,
                        isSelected: coordinator.selectedPreset?.id == preset.id,
                        onSelect: { coordinator.selectPreset(preset) }
                    )
                }
            }

            if let preset = coordinator.selectedPreset, !preset.gestures.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mappings:")
                        .font(.caption.bold())
                    ForEach(GestureType.allCases, id: \.self) { gesture in
                        if let shortcut = preset.gestures[gesture.rawValue] {
                            HStack {
                                Text(gesture.displayName)
                                    .font(.caption)
                                Spacer()
                                Text(shortcut.stringValue)
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(.quaternary)
                .cornerRadius(8)
            }
        }
    }
}

private struct PresetCard: View {
    let preset: GesturePreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.title2)
                Text(preset.displayName)
                    .font(.subheadline.bold())
                Text(preset.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Practice Step

private struct PracticeStepView: View {
    let coordinator: OnboardingCoordinator
    let appCoordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 20) {
            Text("Practice Gestures")
                .font(.title2.bold())

            Text("Perform each gesture to verify it works. Hold one finger, then tap another in the indicated direction.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)

            if coordinator.isCalibrating {
                VStack(spacing: 12) {
                    ForEach(GestureType.allCases, id: \.self) { gesture in
                        CalibrationRow(
                            gesture: gesture,
                            attempts: coordinator.calibrationResults[gesture] ?? [],
                            maxAttempts: coordinator.attemptsPerGesture,
                            isCurrent: coordinator.currentCalibrationGesture == gesture
                        )
                    }
                }

                if let current = coordinator.currentCalibrationGesture {
                    Text("Try: \(current.displayName)")
                        .font(.headline)
                        .padding(.top, 8)
                }

                // Listen for recognized gestures
                if let lastGesture = appCoordinator.lastGesture,
                   coordinator.currentCalibrationGesture == lastGesture {
                    Color.clear
                        .onAppear {
                            coordinator.recordCalibrationAttempt(gesture: lastGesture, success: true)
                        }
                }
            } else {
                Button("Start Practice") {
                    coordinator.startCalibration()
                }
                .controlSize(.large)
            }

            if coordinator.calibrationPassed {
                Label("All gestures verified!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
}

private struct CalibrationRow: View {
    let gesture: GestureType
    let attempts: [Bool]
    let maxAttempts: Int
    let isCurrent: Bool

    var body: some View {
        HStack {
            Text(gesture.displayName)
                .font(.body)
                .foregroundColor(isCurrent ? .primary : .secondary)
                .frame(width: 120, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(0..<maxAttempts, id: \.self) { index in
                    if index < attempts.count {
                        Image(systemName: attempts[index] ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(attempts[index] ? .green : .red)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                }
            }

            if isCurrent {
                Image(systemName: "arrow.left")
                    .foregroundColor(.accentColor)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Confirm Step

private struct ConfirmStepView: View {
    let coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Ready to Go!")
                .font(.title2.bold())

            if let preset = coordinator.selectedPreset {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preset: \(preset.displayName)")
                        .font(.subheadline)

                    if !preset.gestures.isEmpty {
                        ForEach(GestureType.allCases, id: \.self) { gesture in
                            if let shortcut = preset.gestures[gesture.rawValue] {
                                HStack {
                                    Text(gesture.displayName)
                                    Spacer()
                                    Text(shortcut.stringValue)
                                        .monospaced()
                                        .foregroundColor(.secondary)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
                .padding()
                .background(.quaternary)
                .cornerRadius(8)
                .frame(maxWidth: 300)
            }

            if coordinator.calibrationPassed {
                Label("All gestures verified", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Navigation Bar

private struct NavigationBar: View {
    let coordinator: OnboardingCoordinator
    let appCoordinator: AppCoordinator
    let dismiss: DismissAction

    var body: some View {
        HStack {
            if coordinator.currentStep != .permission {
                Button("Back") {
                    coordinator.goBack()
                }
            }

            Spacer()

            switch coordinator.currentStep {
            case .permission:
                Button("Next") {
                    coordinator.advanceStep()
                }
                .disabled(coordinator.permissionState != .granted)

            case .preset:
                Button("Next") {
                    coordinator.advanceStep()
                }
                .disabled(coordinator.selectedPreset == nil)

            case .practice:
                Button("Skip") {
                    coordinator.finishCalibration()
                    coordinator.advanceStep()
                }

                if coordinator.calibrationPassed || !coordinator.isCalibrating {
                    Button("Next") {
                        coordinator.finishCalibration()
                        coordinator.advanceStep()
                    }
                }

            case .confirm:
                Button("Start GestureFire") {
                    coordinator.complete()
                    appCoordinator.finishOnboarding()
                    appCoordinator.start()
                    dismiss()
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}
