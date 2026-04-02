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
    private func makeCoordinator(
        directory: URL? = nil
    ) -> (OnboardingCoordinator, ConfigStore, MockEngineDelegate, URL) {
        let dir = directory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("gesturefire-test-\(UUID().uuidString)")
        let persistence = InMemoryPersistence()
        let configStore = ConfigStore(persistence: persistence)
        let recorder = SampleRecorder(sensitivity: .defaults, directory: dir)
        let delegate = MockEngineDelegate()
        let coordinator = OnboardingCoordinator(
            configStore: configStore,
            sampleRecorder: recorder,
            engineDelegate: delegate
        )
        return (coordinator, configStore, delegate, dir)
    }

    @Test("Initial step is permission")
    @MainActor
    func initialStep() {
        let (coordinator, _, _, _) = makeCoordinator()
        #expect(coordinator.currentStep == .permission)
    }

    @Test("advanceStep progresses through all steps")
    @MainActor
    func advanceStepProgression() {
        let (coordinator, _, _, _) = makeCoordinator()
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
        let (coordinator, _, _, _) = makeCoordinator()
        coordinator.goBack()
        #expect(coordinator.currentStep == .permission)
    }

    @Test("goBack moves to previous step")
    @MainActor
    func goBackWorks() {
        let (coordinator, _, _, _) = makeCoordinator()
        coordinator.advanceStep() // → preset
        coordinator.advanceStep() // → practice
        coordinator.goBack()       // → preset
        #expect(coordinator.currentStep == .preset)
    }

    @Test("selectPreset updates selectedPreset")
    @MainActor
    func selectPreset() {
        let (coordinator, _, _, _) = makeCoordinator()
        coordinator.selectPreset(.browser)
        #expect(coordinator.selectedPreset == .browser)
    }

    @Test("startCalibration initializes tracking and starts recording")
    @MainActor
    func startCalibration() {
        let (coordinator, _, delegate, _) = makeCoordinator()
        coordinator.startCalibration()
        #expect(coordinator.isCalibrating)
        #expect(coordinator.currentCalibrationGesture == GestureType.allCases.first)
        #expect(delegate.startCount == 1)
        #expect(coordinator.recordedSampleURLs.isEmpty)
        for gesture in GestureType.allCases {
            #expect(coordinator.calibrationResults[gesture] != nil)
            #expect(coordinator.calibrationResults[gesture]?.isEmpty == true)
        }
    }

    @Test("Correct gesture recognition saves sample and advances")
    @MainActor
    func correctGestureSavesSample() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (coordinator, _, _, _) = makeCoordinator(directory: dir)
        coordinator.startCalibration()

        let first = GestureType.allCases[0]
        let second = GestureType.allCases[1]

        // Feed a frame so the sample has content
        feedFrame(to: coordinator)

        // Recognize correct gesture 3 times
        let result1 = coordinator.handleRecognizedGesture(first)
        #expect(result1 == true)
        #expect(coordinator.recordedSampleURLs.count == 1)

        feedFrame(to: coordinator)
        coordinator.handleRecognizedGesture(first)
        feedFrame(to: coordinator)
        coordinator.handleRecognizedGesture(first)

        #expect(coordinator.attemptCount(for: first) == 3)
        #expect(coordinator.successCount(for: first) == 3)
        #expect(coordinator.recordedSampleURLs.count == 3)
        // Should have advanced to second gesture
        #expect(coordinator.currentCalibrationGesture == second)
    }

    @Test("Wrong gesture does not save sample and marks failure")
    @MainActor
    func wrongGestureNoSample() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (coordinator, _, _, _) = makeCoordinator(directory: dir)
        coordinator.startCalibration()

        let first = GestureType.allCases[0]
        let wrong = GestureType.allCases[1]

        feedFrame(to: coordinator)

        let result = coordinator.handleRecognizedGesture(wrong)
        #expect(result == false)
        #expect(coordinator.recordedSampleURLs.isEmpty)
        #expect(coordinator.calibrationResults[first]?.first == false)
    }

    @Test("Full calibration produces samples for all gestures")
    @MainActor
    func fullCalibrationProducesSamples() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (coordinator, _, _, _) = makeCoordinator(directory: dir)
        coordinator.startCalibration()

        for gesture in GestureType.allCases {
            for _ in 0..<coordinator.attemptsPerGesture {
                feedFrame(to: coordinator)
                coordinator.handleRecognizedGesture(gesture)
            }
        }

        #expect(coordinator.calibrationPassed)
        // 4 gestures × 3 attempts = 12 samples
        let expectedCount = GestureType.allCases.count * coordinator.attemptsPerGesture
        #expect(coordinator.recordedSampleURLs.count == expectedCount)

        // Verify files exist and are loadable
        let player = SamplePlayer()
        for url in coordinator.recordedSampleURLs {
            let sample = try player.load(from: url)
            #expect(sample.frames.count > 0)
        }

        // Verify samples directory has files
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "gesturesample" }
        #expect(files.count == expectedCount)
    }

    @Test("Cancel/skip during calibration does not produce dirty samples")
    @MainActor
    func cancelDoesNotProduceDirtySamples() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (coordinator, _, _, _) = makeCoordinator(directory: dir)
        coordinator.startCalibration()

        // Feed frames but then finish calibration without completing
        feedFrame(to: coordinator)
        feedFrame(to: coordinator)
        coordinator.finishCalibration()

        #expect(coordinator.recordedSampleURLs.isEmpty)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        #expect(files.isEmpty)
    }

    @Test("calibrationPassed requires at least one success per gesture")
    @MainActor
    func calibrationPassedCheck() {
        let (coordinator, _, _, _) = makeCoordinator()
        coordinator.startCalibration()

        // Not passed initially
        #expect(!coordinator.calibrationPassed)

        // Record at least one success for each gesture
        for gesture in GestureType.allCases {
            for _ in 0..<coordinator.attemptsPerGesture {
                feedFrame(to: coordinator)
                coordinator.handleRecognizedGesture(gesture)
            }
        }

        #expect(coordinator.calibrationPassed)
    }

    @Test("complete saves config with preset gestures and sets onboarding flag")
    @MainActor
    func completeOnboarding() {
        let (coordinator, configStore, _, _) = makeCoordinator()
        coordinator.selectPreset(.browser)
        coordinator.complete()

        #expect(configStore.config.hasCompletedOnboarding == true)
        #expect(configStore.config.gestures == GesturePreset.browser.gestures)
    }

    @Test("complete without preset does not change config")
    @MainActor
    func completeWithoutPreset() {
        let (coordinator, configStore, _, _) = makeCoordinator()
        // No preset selected
        coordinator.complete()
        #expect(configStore.config.hasCompletedOnboarding == false)
    }

    @Test("finishCalibration clears calibration state and cancels recording")
    @MainActor
    func finishCalibration() {
        let (coordinator, _, _, _) = makeCoordinator()
        coordinator.startCalibration()
        coordinator.finishCalibration()
        #expect(!coordinator.isCalibrating)
        #expect(coordinator.currentCalibrationGesture == nil)
    }

    // MARK: - Helpers

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gesturefire-onboarding-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Feed a dummy frame through the coordinator's sample recorder.
    /// The recorder must be recording for this to have effect.
    @MainActor
    private func feedFrame(to coordinator: OnboardingCoordinator) {
        let point = TouchPoint(
            id: 1,
            position: SIMD2(0.5, 0.5),
            state: .touching,
            timestamp: Date()
        )
        coordinator.feedFrameToRecorder(
            TouchFrame(points: [point], timestamp: Date())
        )
    }
}
