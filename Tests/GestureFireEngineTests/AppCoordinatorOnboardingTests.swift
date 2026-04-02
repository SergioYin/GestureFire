import Foundation
import Testing
@testable import GestureFireConfig
@testable import GestureFireEngine
import GestureFireTypes

@Suite("AppCoordinator Onboarding Lifecycle")
struct AppCoordinatorOnboardingTests {

    @MainActor
    private func makeCoordinator(hasCompletedOnboarding: Bool = false) -> AppCoordinator {
        let storage = InMemoryPersistence.Storage()
        storage.config = GestureFireConfig(
            gestures: hasCompletedOnboarding
                ? GesturePreset.browser.gestures
                : [:],
            hasCompletedOnboarding: hasCompletedOnboarding
        )
        let persistence = InMemoryPersistence(storage: storage)
        let configStore = ConfigStore(persistence: persistence)
        return AppCoordinator(configStore: configStore)
    }

    @Test("needsOnboarding is true for fresh config")
    @MainActor
    func needsOnboardingFresh() {
        let coordinator = makeCoordinator(hasCompletedOnboarding: false)
        #expect(coordinator.needsOnboarding == true)
    }

    @Test("needsOnboarding is false after completion")
    @MainActor
    func needsOnboardingAfterComplete() {
        let coordinator = makeCoordinator(hasCompletedOnboarding: true)
        #expect(coordinator.needsOnboarding == false)
    }

    @Test("beginOnboarding creates non-nil onboardingCoordinator")
    @MainActor
    func beginOnboardingCreatesCoordinator() {
        let coordinator = makeCoordinator()
        #expect(coordinator.onboardingCoordinator == nil)
        coordinator.beginOnboarding()
        #expect(coordinator.onboardingCoordinator != nil)
    }

    @Test("finishOnboarding nils onboardingCoordinator")
    @MainActor
    func finishOnboardingNilsCoordinator() {
        let coordinator = makeCoordinator()
        coordinator.beginOnboarding()
        #expect(coordinator.onboardingCoordinator != nil)
        coordinator.finishOnboarding()
        #expect(coordinator.onboardingCoordinator == nil)
    }

    @Test("Repeated beginOnboarding after finish creates fresh coordinator")
    @MainActor
    func repeatedBeginOnboarding() {
        let coordinator = makeCoordinator()

        coordinator.beginOnboarding()
        let first = coordinator.onboardingCoordinator
        #expect(first != nil)

        coordinator.finishOnboarding()
        #expect(coordinator.onboardingCoordinator == nil)

        coordinator.beginOnboarding()
        let second = coordinator.onboardingCoordinator
        #expect(second != nil)
        #expect(first !== second)
    }

    @Test("beginOnboarding for returning user loads preset from config")
    @MainActor
    func beginOnboardingLoadsPreset() {
        let coordinator = makeCoordinator(hasCompletedOnboarding: true)
        coordinator.beginOnboarding()

        let onboarding = coordinator.onboardingCoordinator
        #expect(onboarding != nil)
        // Should have matched browser preset from config gestures
        #expect(onboarding?.selectedPreset == .browser)
    }

    @Test("beginOnboarding for returning user with custom gestures loads custom preset")
    @MainActor
    func beginOnboardingLoadsCustomPreset() {
        let storage = InMemoryPersistence.Storage()
        let customGestures = [
            GestureType.tipTapLeft.rawValue: try! KeyShortcut.parse("cmd+z"),
            GestureType.tipTapRight.rawValue: try! KeyShortcut.parse("cmd+y"),
        ]
        storage.config = GestureFireConfig(
            gestures: customGestures,
            hasCompletedOnboarding: true
        )
        let persistence = InMemoryPersistence(storage: storage)
        let configStore = ConfigStore(persistence: persistence)
        let coordinator = AppCoordinator(configStore: configStore)

        coordinator.beginOnboarding()

        let onboarding = coordinator.onboardingCoordinator
        #expect(onboarding?.selectedPreset?.id == "custom")
        #expect(onboarding?.selectedPreset?.gestures == customGestures)
    }

    @Test("beginOnboarding without finishOnboarding replaces coordinator")
    @MainActor
    func beginOnboardingReplacesWithoutFinish() {
        let coordinator = makeCoordinator()

        coordinator.beginOnboarding()
        let first = coordinator.onboardingCoordinator
        #expect(first != nil)

        // Call beginOnboarding again WITHOUT finishOnboarding
        // (simulates: user closed wizard via X, then clicks Setup Wizard again)
        coordinator.beginOnboarding()
        let second = coordinator.onboardingCoordinator
        #expect(second != nil)
        #expect(first !== second)
    }

    @Test("beginOnboarding always produces non-nil coordinator regardless of prior state")
    @MainActor
    func beginOnboardingAlwaysProducesCoordinator() {
        let coordinator = makeCoordinator(hasCompletedOnboarding: true)

        // Scenario: completed user, beginOnboarding called multiple times
        for _ in 0..<5 {
            coordinator.beginOnboarding()
            #expect(coordinator.onboardingCoordinator != nil)
            coordinator.finishOnboarding()
            #expect(coordinator.onboardingCoordinator == nil)
        }
    }
}

// MARK: - Helpers

extension InMemoryPersistence {
    /// Init with pre-populated storage for testing.
    init(storage: Storage) {
        self.storage = storage
    }
}
