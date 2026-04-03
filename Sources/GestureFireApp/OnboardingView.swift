import GestureFireConfig
import GestureFireEngine
import GestureFireTypes
import SwiftUI

/// 4-step onboarding wizard.
struct OnboardingView: View {
    let coordinator: OnboardingCoordinator
    let appCoordinator: AppCoordinator
    /// Closure to close the hosting window (NSWindow or SwiftUI dismiss).
    var onDismiss: (() -> Void)?

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
            NavigationBar(coordinator: coordinator, appCoordinator: appCoordinator, onDismiss: onDismiss)
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

    private static let steps = OnboardingCoordinator.Step.allCases

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.steps.enumerated()), id: \.element.rawValue) { index, step in
                if index > 0 {
                    // Connecting line
                    Rectangle()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                }

                // Numbered pill
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 24, height: 24)
                        if step < currentStep {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(step <= currentStep ? .white : .secondary)
                        }
                    }
                    Text(stepLabel(step))
                        .font(.caption)
                        .foregroundStyle(step == currentStep ? .primary : .secondary)
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
                .foregroundStyle(Color.accentColor)

            Text("Accessibility Permission")
                .font(.title2.bold())

            Text("GestureFire needs accessibility access to detect trackpad gestures and simulate keyboard shortcuts.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            switch coordinator.permissionState {
            case .unknown, .denied:
                VStack(spacing: 8) {
                    Button("Open System Settings") {
                        coordinator.requestPermission()
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)

                    Text("You'll be asked to allow GestureFire in Accessibility settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if coordinator.permissionState == .denied {
                    Text("Permission was denied. Click above to try again.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

            case .requested:
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for permission...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Open System Settings → Privacy & Security → Accessibility")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button("Denied? Try Again") {
                        coordinator.resetPermissionState()
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }

            case .granted:
                Label("Permission Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
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
                .foregroundStyle(.secondary)

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
                                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
    /// Snapshot of gestureCount to detect new recognitions (including same gesture twice).
    @State private var lastSeenGestureCount = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("Test Your Gestures")
                .font(.title2.bold())

            Text("Perform each gesture to verify it works. Hold one finger, then tap another in the indicated direction.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            // Always show the gesture grid so user sees what's expected
            VStack(spacing: 12) {
                ForEach(GestureType.allCases, id: \.self) { gesture in
                    CalibrationRow(
                        gesture: gesture,
                        attempts: coordinator.calibrationResults[gesture] ?? [],
                        maxAttempts: coordinator.attemptsPerGesture,
                        isCurrent: coordinator.isCalibrating && coordinator.currentCalibrationGesture == gesture
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            if coordinator.isCalibrating {
                if let current = coordinator.currentCalibrationGesture {
                    Text("Try: \(current.displayName)")
                        .font(.headline)
                } else {
                    Text(" ")
                        .font(.headline)
                }
            } else if !coordinator.calibrationPassed {
                Button("Start Gesture Test") {
                    lastSeenGestureCount = appCoordinator.gestureCount
                    coordinator.startCalibration()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }

            if coordinator.calibrationPassed {
                Label("All gestures verified!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            if let error = coordinator.lastSampleSaveError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if !coordinator.recordedSampleURLs.isEmpty {
                Text("\(coordinator.recordedSampleURLs.count) sample(s) recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        // Detect ANY new gesture recognition by watching gestureCount changes.
        .onChange(of: appCoordinator.gestureCount) { _, newCount in
            guard coordinator.isCalibrating,
                  newCount > lastSeenGestureCount,
                  let recognized = appCoordinator.lastGesture else { return }
            lastSeenGestureCount = newCount
            coordinator.handleRecognizedGesture(recognized)
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
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .frame(minWidth: 100, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(0..<maxAttempts, id: \.self) { index in
                    if index < attempts.count {
                        Image(systemName: attempts[index] ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(attempts[index] ? .green : .red)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
                }
            }

            if isCurrent {
                Image(systemName: "arrow.left")
                    .foregroundStyle(Color.accentColor)
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
                .foregroundStyle(.green)

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
                                        .foregroundStyle(.secondary)
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

            // Practice results summary
            VStack(spacing: 4) {
                if coordinator.calibrationPassed {
                    Label("All gestures verified", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    let verified = coordinator.calibrationResults.values.filter { results in
                        results.contains(true)
                    }.count
                    let total = GestureType.allCases.count
                    Label("\(verified)/\(total) gestures verified", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(verified > 0 ? .blue : .secondary)
                }

                if !coordinator.recordedSampleURLs.isEmpty {
                    Text("\(coordinator.recordedSampleURLs.count) sample(s) recorded")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Navigation Bar

private struct NavigationBar: View {
    let coordinator: OnboardingCoordinator
    let appCoordinator: AppCoordinator
    var onDismiss: (() -> Void)?

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
                Button("Skip Practice") {
                    coordinator.finishCalibration()
                    coordinator.advanceStep()
                }
                .help("You can test gestures later from the menu bar")

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
                    if !appCoordinator.engineState.isOperational {
                        appCoordinator.start()
                    }
                    onDismiss?()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}
