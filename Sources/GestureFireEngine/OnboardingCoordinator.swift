import ApplicationServices
import Foundation
import GestureFireConfig
import GestureFireTypes
import Observation
import os

// MARK: - Engine Delegate Protocol

/// Decouples OnboardingCoordinator from AppCoordinator for testability.
@MainActor
public protocol OnboardingEngineDelegate: AnyObject {
    func startEngine()
    func stopEngine()
    var engineState: EngineState { get }
}

// MARK: - Onboarding Coordinator

/// State machine driving the 4-step onboarding wizard.
/// @MainActor @Observable for direct SwiftUI binding.
@MainActor
@Observable
public final class OnboardingCoordinator {

    // MARK: - Step enum

    public enum Step: Int, CaseIterable, Comparable, Sendable {
        case permission = 0
        case preset = 1
        case practice = 2
        case confirm = 3

        public static func < (lhs: Step, rhs: Step) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Permission state

    public enum PermissionState: Sendable, Equatable {
        case unknown
        case granted
        case denied
        case requested
    }

    // MARK: - Observable state

    public private(set) var currentStep: Step = .permission
    public private(set) var permissionState: PermissionState = .unknown
    public var selectedPreset: GesturePreset?

    /// Calibration results: gesture → array of success/fail per attempt.
    public private(set) var calibrationResults: [GestureType: [Bool]] = [:]
    public private(set) var currentCalibrationGesture: GestureType?
    public private(set) var isCalibrating = false

    /// URLs of successfully recorded .gesturesample files.
    public private(set) var recordedSampleURLs: [URL] = []

    /// Last sample save error, if any. Cleared on next successful save.
    public private(set) var lastSampleSaveError: String?

    /// How many attempts per gesture during calibration.
    public let attemptsPerGesture = 3

    // MARK: - Dependencies

    @ObservationIgnored private let configStore: ConfigStore
    @ObservationIgnored private let sampleRecorder: SampleRecorder
    @ObservationIgnored private weak var engineDelegate: (any OnboardingEngineDelegate)?
    @ObservationIgnored private var permissionPollTask: Task<Void, Never>?

    private static let logger = Logger(subsystem: "com.gesturefire", category: "onboarding")

    // MARK: - Init

    public init(
        configStore: ConfigStore,
        sampleRecorder: SampleRecorder,
        engineDelegate: (any OnboardingEngineDelegate)? = nil
    ) {
        self.configStore = configStore
        self.sampleRecorder = sampleRecorder
        self.engineDelegate = engineDelegate
    }

    deinit {
        permissionPollTask?.cancel()
    }

    // MARK: - Step Navigation

    public func advanceStep() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
        Self.logger.info("Onboarding advanced to step \(next.rawValue)")
    }

    public func goBack() {
        guard let prev = Step(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    public func goToStep(_ step: Step) {
        currentStep = step
    }

    // MARK: - Permission

    /// Check current accessibility permission state (read-only, no dialog).
    public func checkPermission() {
        if AXIsProcessTrusted() {
            permissionState = .granted
        } else if permissionState != .requested {
            permissionState = .denied
        }
    }

    /// Request accessibility permission (shows system dialog once).
    public func requestPermission() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        permissionState = .requested
        startPermissionPolling()
    }

    /// Reset from "waiting" back to actionable state so user can retry.
    public func resetPermissionState() {
        permissionPollTask?.cancel()
        permissionPollTask = nil
        permissionState = AXIsProcessTrusted() ? .granted : .denied
    }

    /// Poll until permission is granted. If not granted after 30 polls (~30s),
    /// reset to `.denied` so the user can click "Grant Access" again.
    private func startPermissionPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = Task { [weak self] in
            var pollCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { break }
                pollCount += 1
                if AXIsProcessTrusted() {
                    self.permissionState = .granted
                    Self.logger.info("Permission granted during onboarding")
                    break
                }
                // After ~30 seconds of waiting, reset so user can retry
                if pollCount >= 30 {
                    self.permissionState = .denied
                    Self.logger.info("Permission poll timed out — reset to denied")
                    break
                }
            }
        }
    }

    // MARK: - Preset Selection

    public func selectPreset(_ preset: GesturePreset) {
        selectedPreset = preset
        Self.logger.info("Selected preset: \(preset.id)")
    }

    // MARK: - Calibration (Practice Step)

    /// Start calibration: engine starts, iterate through gestures.
    public func startCalibration() {
        isCalibrating = true
        calibrationResults = [:]
        recordedSampleURLs = []
        for gesture in GestureType.allCases {
            calibrationResults[gesture] = []
        }
        currentCalibrationGesture = GestureType.allCases.first
        engineDelegate?.startEngine()

        // Begin recording for the first gesture
        if let first = currentCalibrationGesture {
            sampleRecorder.startRecording(for: first)
        }

        Self.logger.info("Calibration started")
    }

    /// Handle a recognized gesture during calibration.
    /// Returns true if it was a valid attempt for the current target gesture.
    @discardableResult
    public func handleRecognizedGesture(_ gesture: GestureType) -> Bool {
        guard isCalibrating, let current = currentCalibrationGesture else { return false }

        if gesture == current {
            // Correct gesture — finish recording and save sample
            do {
                let url = try sampleRecorder.finishRecording()
                recordedSampleURLs.append(url)
                lastSampleSaveError = nil
                Self.logger.info("Saved sample: \(url.lastPathComponent)")
            } catch {
                lastSampleSaveError = "Sample save failed: \(error.localizedDescription)"
                Self.logger.warning("Failed to save sample: \(error)")
            }
            calibrationResults[current, default: []].append(true)

            // Check if this gesture has enough attempts
            if (calibrationResults[current]?.count ?? 0) >= attemptsPerGesture {
                moveToNextCalibrationGesture()
            } else {
                // More attempts needed — start new recording for same gesture
                sampleRecorder.startRecording(for: current)
            }
            return true
        } else {
            // Wrong gesture — cancel the dirty recording and restart
            sampleRecorder.cancelRecording()
            calibrationResults[current, default: []].append(false)
            Self.logger.info("Wrong gesture: expected \(current.rawValue), got \(gesture.rawValue)")

            // Check if this gesture has enough attempts (including failures)
            if (calibrationResults[current]?.count ?? 0) >= attemptsPerGesture {
                moveToNextCalibrationGesture()
            } else {
                // Restart recording for same gesture
                sampleRecorder.startRecording(for: current)
            }
            return false
        }
    }

    private func moveToNextCalibrationGesture() {
        // Cancel any in-progress recording before switching
        if sampleRecorder.isRecording {
            sampleRecorder.cancelRecording()
        }

        guard let current = currentCalibrationGesture,
              let currentIndex = GestureType.allCases.firstIndex(of: current) else {
            finishCalibration()
            return
        }
        let nextIndex = GestureType.allCases.index(after: currentIndex)
        if nextIndex < GestureType.allCases.endIndex {
            let next = GestureType.allCases[nextIndex]
            currentCalibrationGesture = next
            sampleRecorder.startRecording(for: next)
        } else {
            finishCalibration()
        }
    }

    /// End calibration. Cancels any in-progress recording.
    public func finishCalibration() {
        if sampleRecorder.isRecording {
            sampleRecorder.cancelRecording()
        }
        isCalibrating = false
        currentCalibrationGesture = nil
        Self.logger.info("Calibration finished — \(self.recordedSampleURLs.count) samples recorded")
    }

    /// Whether all gestures have at least one successful attempt.
    public var calibrationPassed: Bool {
        GestureType.allCases.allSatisfy { gesture in
            calibrationResults[gesture]?.contains(true) == true
        }
    }

    /// Number of completed attempts for a gesture.
    public func attemptCount(for gesture: GestureType) -> Int {
        calibrationResults[gesture]?.count ?? 0
    }

    /// Number of successful attempts for a gesture.
    public func successCount(for gesture: GestureType) -> Int {
        calibrationResults[gesture]?.filter { $0 }.count ?? 0
    }

    // MARK: - Frame Recording (exposed for testing and AppCoordinator integration)

    /// Forward a frame to the sample recorder. Called by AppCoordinator's handleFrame.
    public func feedFrameToRecorder(_ frame: TouchFrame) {
        sampleRecorder.recordFrame(frame)
    }

    // MARK: - Completion

    /// Save config with selected preset and mark onboarding complete.
    public func complete() {
        guard let preset = selectedPreset else {
            Self.logger.warning("Cannot complete onboarding: no preset selected")
            return
        }

        configStore.update { config in
            // Only overwrite gestures if user selected a non-empty preset
            // or explicitly chose custom (empty). Preserves existing mappings
            // when a returning user re-runs the wizard without changing preset.
            if !preset.gestures.isEmpty || config.gestures.isEmpty {
                config.gestures = preset.gestures
            }
            config.hasCompletedOnboarding = true
        }

        permissionPollTask?.cancel()
        Self.logger.info("Onboarding completed with preset: \(preset.id)")
    }
}
