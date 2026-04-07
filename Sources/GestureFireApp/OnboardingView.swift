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
            // Fixed top: step indicator
            StepIndicator(currentStep: coordinator.currentStep)
                .padding(Spacing.lg)

            Divider()

            // Fixed center: step content in a stable frame
            // Each step is wrapped in ScrollView so content can grow without
            // pushing the navigation bar off screen or causing layout jumps.
            ScrollView {
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
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Fixed bottom: navigation bar
            NavigationBar(coordinator: coordinator, appCoordinator: appCoordinator, onDismiss: onDismiss)
                .padding(Spacing.lg)
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
                    Rectangle()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(height: 2)
                        .frame(maxWidth: 48)
                }

                HStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(width: 32, height: 32)
                        if step < currentStep {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.callout.bold())
                                .foregroundStyle(step <= currentStep ? .white : .secondary)
                        }
                    }
                    Text(stepLabel(step))
                        .font(.subheadline)
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
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 96, height: 96)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
            }

            Text("Accessibility Permission")
                .font(.title2.bold())

            Text("GestureFire needs accessibility access to detect trackpad gestures and simulate keyboard shortcuts.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            // Fixed-height action area prevents layout jumping between states
            VStack(spacing: Spacing.sm) {
                switch coordinator.permissionState {
                case .unknown, .denied:
                    Button("Open System Settings") {
                        coordinator.requestPermission()
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)

                    Text(coordinator.permissionState == .denied
                         ? "Permission was denied. Click above to try again."
                         : "You'll be asked to allow GestureFire in Accessibility settings.")
                        .font(.caption)
                        .foregroundStyle(coordinator.permissionState == .denied ? .orange : .secondary)

                case .requested:
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
                    .padding(.top, Spacing.xs)

                case .granted:
                    StatusBadge(title: "Permission Granted", systemImage: "checkmark.circle.fill", color: .green)
                        .font(.title3)
                }
            }
            .frame(minHeight: 80)
        }
    }
}

// MARK: - Preset Step

private struct PresetStepView: View {
    let coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Choose a Preset")
                .font(.title2.bold())

            Text("Select a gesture-to-shortcut mapping to get started.")
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: Spacing.md) {
                ForEach(GesturePreset.allPresets) { preset in
                    PresetCard(
                        preset: preset,
                        isSelected: coordinator.selectedPreset?.id == preset.id,
                        onSelect: { coordinator.selectPreset(preset) }
                    )
                }
            }

            if let preset = coordinator.selectedPreset, !preset.gestures.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
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
                .padding(Spacing.md)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
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
            HStack(spacing: 0) {
                // Accent bar on selected card
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 4)
                }

                VStack(spacing: Spacing.sm) {
                    Image(systemName: preset.icon)
                        .font(.title)
                    Text(preset.displayName)
                        .font(.subheadline.bold())
                    Text(preset.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding(Spacing.md)
            }
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.1)
                    : Color(.controlBackgroundColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Practice Step

private struct PracticeStepView: View {
    let coordinator: OnboardingCoordinator
    let appCoordinator: AppCoordinator
    @State private var lastSeenGestureCount = 0

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Test Your Gestures")
                .font(.title2.bold())

            Text("Perform each gesture to verify it works. Hold one finger, then tap another in the indicated direction.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            // Calibration grid inside a card — always visible, stable structure
            VStack(spacing: Spacing.sm) {
                ForEach(GestureType.allCases, id: \.self) { gesture in
                    CalibrationRow(
                        gesture: gesture,
                        attempts: coordinator.calibrationResults[gesture] ?? [],
                        maxAttempts: coordinator.attemptsPerGesture,
                        isCurrent: coordinator.isCalibrating && coordinator.currentCalibrationGesture == gesture
                    )
                }
            }
            .padding(Spacing.lg)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))

            // Fixed-height action area — always occupies space to prevent jumping
            VStack(spacing: Spacing.sm) {
                if coordinator.calibrationPassed {
                    StatusBadge(title: "All gestures verified!", systemImage: "checkmark.circle.fill", color: .green)
                } else if coordinator.isCalibrating {
                    Text("Try: \(coordinator.currentCalibrationGesture?.displayName ?? "...")")
                        .font(.headline)
                } else {
                    Button("Start Gesture Test") {
                        lastSeenGestureCount = appCoordinator.gestureCount
                        coordinator.startCalibration()
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                }

                // Secondary info — always reserve the line, use opacity to show/hide
                Group {
                    if let error = coordinator.lastSampleSaveError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else if !coordinator.recordedSampleURLs.isEmpty {
                        Text("\(coordinator.recordedSampleURLs.count) sample(s) recorded")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(" ")
                    }
                }
                .font(.caption)
            }
            .frame(minHeight: 60)
        }
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

            HStack(spacing: Spacing.sm) {
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
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(
            isCurrent
                ? Color.accentColor.opacity(0.06)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }
}

// MARK: - Confirm Step

private struct ConfirmStepView: View {
    let coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
            }

            Text("Ready to Go!")
                .font(.title2.bold())

            if let preset = coordinator.selectedPreset {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Preset: \(preset.displayName)")
                        .font(.subheadline.weight(.medium))

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
                .padding(Spacing.lg)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 300)
            }

            // Practice results summary
            VStack(spacing: Spacing.xs) {
                if coordinator.calibrationPassed {
                    StatusBadge(title: "All gestures verified", systemImage: "checkmark.circle", color: .green)
                } else {
                    let verified = coordinator.calibrationResults.values.filter { results in
                        results.contains(true)
                    }.count
                    let total = GestureType.allCases.count
                    StatusBadge(
                        title: "\(verified)/\(total) gestures verified",
                        systemImage: "info.circle",
                        color: verified > 0 ? .blue : .secondary
                    )
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
            // Back button — always present but hidden on first step to prevent layout shift
            Button("Back") {
                coordinator.goBack()
            }
            .opacity(coordinator.currentStep != .permission ? 1 : 0)
            .disabled(coordinator.currentStep == .permission)

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

                Button("Next") {
                    coordinator.finishCalibration()
                    coordinator.advanceStep()
                }
                .opacity(coordinator.calibrationPassed || !coordinator.isCalibrating ? 1 : 0)
                .disabled(!(coordinator.calibrationPassed || !coordinator.isCalibrating))

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
