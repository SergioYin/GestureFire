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

    /// Poll until permission is granted or task is cancelled.
    private func startPermissionPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { break }
                if AXIsProcessTrusted() {
                    self.permissionState = .granted
                    Self.logger.info("Permission granted during onboarding")
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
        for gesture in GestureType.allCases {
            calibrationResults[gesture] = []
        }
        currentCalibrationGesture = GestureType.allCases.first
        engineDelegate?.startEngine()
        Self.logger.info("Calibration started")
    }

    /// Record one calibration attempt result.
    public func recordCalibrationAttempt(gesture: GestureType, success: Bool) {
        calibrationResults[gesture, default: []].append(success)

        // Move to next gesture if this one has enough attempts
        if let current = currentCalibrationGesture,
           (calibrationResults[current]?.count ?? 0) >= attemptsPerGesture {
            moveToNextCalibrationGesture()
        }
    }

    private func moveToNextCalibrationGesture() {
        guard let current = currentCalibrationGesture,
              let currentIndex = GestureType.allCases.firstIndex(of: current) else {
            finishCalibration()
            return
        }
        let nextIndex = GestureType.allCases.index(after: currentIndex)
        if nextIndex < GestureType.allCases.endIndex {
            currentCalibrationGesture = GestureType.allCases[nextIndex]
        } else {
            finishCalibration()
        }
    }

    /// End calibration.
    public func finishCalibration() {
        isCalibrating = false
        currentCalibrationGesture = nil
        Self.logger.info("Calibration finished")
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

    // MARK: - Completion

    /// Save config with selected preset and mark onboarding complete.
    public func complete() {
        guard let preset = selectedPreset else {
            Self.logger.warning("Cannot complete onboarding: no preset selected")
            return
        }

        configStore.update { config in
            config.gestures = preset.gestures
            config.hasCompletedOnboarding = true
        }

        permissionPollTask?.cancel()
        Self.logger.info("Onboarding completed with preset: \(preset.id)")
    }
}
