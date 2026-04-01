import Foundation
import Testing
@testable import GestureFireEngine
@testable import GestureFireConfig
import GestureFireTypes

// MARK: - Mock Engine Delegate

@MainActor
final class MockEngineDelegate: OnboardingEngineDelegate {
    var startCount = 0
    var stopCount = 0
    var engineState: EngineState = .disabled

    func startEngine() { startCount += 1 }
    func stopEngine() { stopCount += 1 }
}

// MARK: - Mock Persistence for ConfigStore

struct InMemoryPersistence: ConfigPersisting {
    let storage: Storage

    final class Storage: @unchecked Sendable {
        var config: GestureFireConfig?
    }

    init() { self.storage = Storage() }

    func load() throws -> GestureFireConfig? {
        storage.config
    }

    func save(_ config: GestureFireConfig) throws {
        storage.config = config
    }
}

// MARK: - Tests

@Suite("OnboardingCoordinator")
struct OnboardingCoordinatorTests {

    @MainActor
    private func makeCoordinator() -> (OnboardingCoordinator, ConfigStore, MockEngineDelegate) {
        let persistence = InMemoryPersistence()
        let configStore = ConfigStore(persistence: persistence)
        let recorder = SampleRecorder(sensitivity: .defaults)
        let delegate = MockEngineDelegate()
        let coordinator = OnboardingCoordinator(
            configStore: configStore,
            sampleRecorder: recorder,
            engineDelegate: delegate
        )
        return (coordinator, configStore, delegate)
    }

    @Test("Initial step is permission")
    @MainActor
    func initialStep() {
        let (coordinator, _, _) = makeCoordinator()
        #expect(coordinator.currentStep == .permission)
    }

    @Test("advanceStep progresses through all steps")
    @MainActor
    func advanceStepProgression() {
        let (coordinator, _, _) = makeCoordinator()
        #expect(coordinator.currentStep == .permission)
        coordinator.advanceStep()
        #expect(coordinator.currentStep == .preset)
        coordinator.advanceStep()
        #expect(coordinator.currentStep == .practice)
        coordinator.advanceStep()
        #expect(coordinator.currentStep == .confirm)
        // Can't go past last step
        coordinator.advanceStep()
        #expect(coordinator.currentStep == .confirm)
    }

    @Test("goBack does not go before first step")
    @MainActor
    func goBackBoundary() {
        let (coordinator, _, _) = makeCoordinator()
        coordinator.goBack()
        #expect(coordinator.currentStep == .permission)
    }

    @Test("goBack moves to previous step")
    @MainActor
    func goBackWorks() {
        let (coordinator, _, _) = makeCoordinator()
        coordinator.advanceStep() // → preset
        coordinator.advanceStep() // → practice
        coordinator.goBack()       // → preset
        #expect(coordinator.currentStep == .preset)
    }

    @Test("selectPreset updates selectedPreset")
    @MainActor
    func selectPreset() {
        let (coordinator, _, _) = makeCoordinator()
        coordinator.selectPreset(.browser)
        #expect(coordinator.selectedPreset == .browser)
    }

    @Test("startCalibration initializes tracking for all gestures")
    @MainActor
    func startCalibration() {
        let (coordinator, _, delegate) = makeCoordinator()
        coordinator.startCalibration()
        #expect(coordinator.isCalibrating)
        #expect(coordinator.currentCalibrationGesture == GestureType.allCases.first)
        #expect(delegate.startCount == 1)
        for gesture in GestureType.allCases {
            #expect(coordinator.calibrationResults[gesture] != nil)
            #expect(coordinator.calibrationResults[gesture]?.isEmpty == true)
        }
    }

    @Test("recordCalibrationAttempt tracks results and advances gesture")
    @MainActor
    func calibrationAttempts() {
        let (coordinator, _, _) = makeCoordinator()
        coordinator.startCalibration()
        let firstGesture = GestureType.allCases[0]
        let secondGesture = GestureType.allCases[1]

        // Record 3 attempts for first gesture
        coordinator.recordCalibrationAttempt(gesture: firstGesture, success: true)
        coordinator.recordCalibrationAttempt(gesture: firstGesture, success: false)
        coordinator.recordCalibrationAttempt(gesture: firstGesture, success: true)

        #expect(coordinator.attemptCount(for: firstGesture) == 3)
        #expect(coordinator.successCount(for: firstGesture) == 2)
        // Should have advanced to second gesture
        #expect(coordinator.currentCalibrationGesture == secondGesture)
    }

    @Test("calibrationPassed requires at least one success per gesture")
    @MainActor
    func calibrationPassedCheck() {
        let (coordinator, _, _) = makeCoordinator()
        coordinator.startCalibration()

        // Not passed initially
        #expect(!coordinator.calibrationPassed)

        // Record at least one success for each gesture
        for gesture in GestureType.allCases {
            coordinator.recordCalibrationAttempt(gesture: gesture, success: true)
            coordinator.recordCalibrationAttempt(gesture: gesture, success: true)
            coordinator.recordCalibrationAttempt(gesture: gesture, success: true)
        }

        #expect(coordinator.calibrationPassed)
    }

    @Test("complete saves config with preset gestures and sets onboarding flag")
    @MainActor
    func completeOnboarding() {
        let (coordinator, configStore, _) = makeCoordinator()
        coordinator.selectPreset(.browser)
        coordinator.complete()

        #expect(configStore.config.hasCompletedOnboarding == true)
        #expect(configStore.config.gestures == GesturePreset.browser.gestures)
    }

    @Test("complete without preset does not change config")
    @MainActor
    func completeWithoutPreset() {
        let (coordinator, configStore, _) = makeCoordinator()
        // No preset selected
        coordinator.complete()
        #expect(configStore.config.hasCompletedOnboarding == false)
    }

    @Test("finishCalibration clears calibration state")
    @MainActor
    func finishCalibration() {
        let (coordinator, _, _) = makeCoordinator()
        coordinator.startCalibration()
        coordinator.finishCalibration()
        #expect(!coordinator.isCalibrating)
        #expect(coordinator.currentCalibrationGesture == nil)
    }
}
