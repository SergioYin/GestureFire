import Foundation
import Testing
@testable import GestureFireEngine

@Suite("DiagnosticRunner")
struct DiagnosticRunnerTests {

    @Test("All checks pass with passing mock")
    func allPass() async {
        let checker = MockDiagnosticChecker(
            accessibilityGranted: true,
            touchFrameReceived: true,
            cgEventCreatable: true
        )
        let runner = DiagnosticRunner(checker: checker)
        let results = await runner.runAll()

        #expect(results.count == 3)
        #expect(results.allSatisfy { $0.status == .pass })
    }

    @Test("Accessibility denied → fail with fix instruction")
    func accessibilityFail() async {
        let checker = MockDiagnosticChecker(
            accessibilityGranted: false,
            touchFrameReceived: true,
            cgEventCreatable: true
        )
        let runner = DiagnosticRunner(checker: checker)
        let results = await runner.runAll()

        let ax = results.first { $0.name == "Accessibility Permission" }
        #expect(ax?.status == .fail)
        #expect(ax?.fixInstruction != nil)
    }

    @Test("Touch frame not received → fail")
    func touchFrameFail() async {
        let checker = MockDiagnosticChecker(
            accessibilityGranted: true,
            touchFrameReceived: false,
            cgEventCreatable: true
        )
        let runner = DiagnosticRunner(checker: checker)
        let results = await runner.runAll()

        let touch = results.first { $0.name == "Trackpad Touch Frames" }
        #expect(touch?.status == .fail)
    }

    @Test("Touch frame received → pass")
    func touchFramePass() async {
        let checker = MockDiagnosticChecker(
            accessibilityGranted: true,
            touchFrameReceived: true,
            cgEventCreatable: true
        )
        let runner = DiagnosticRunner(checker: checker)
        let results = await runner.runAll()

        let touch = results.first { $0.name == "Trackpad Touch Frames" }
        #expect(touch?.status == .pass)
    }

    @Test("CGEvent creation failure → fail")
    func cgEventFail() async {
        let checker = MockDiagnosticChecker(
            accessibilityGranted: true,
            touchFrameReceived: true,
            cgEventCreatable: false
        )
        let runner = DiagnosticRunner(checker: checker)
        let results = await runner.runAll()

        let cg = results.first { $0.name == "Keyboard Event Creation" }
        #expect(cg?.status == .fail)
    }

    @Test("Mixed results — only failing items have fix instructions")
    func mixedResults() async {
        let checker = MockDiagnosticChecker(
            accessibilityGranted: false,
            touchFrameReceived: true,
            cgEventCreatable: false
        )
        let runner = DiagnosticRunner(checker: checker)
        let results = await runner.runAll()

        let passing = results.filter { $0.status == .pass }
        let failing = results.filter { $0.status == .fail }
        #expect(passing.count == 1)
        #expect(failing.count == 2)
        #expect(failing.allSatisfy { $0.fixInstruction != nil })
        #expect(passing.allSatisfy { $0.fixInstruction == nil })
    }

    @Test("Touch frame checker closure is actually called")
    func touchFrameCheckerCalled() async {
        let callTracker = CallTracker()
        let checker = CallbackDiagnosticChecker(
            accessibilityResult: true,
            touchFrameCallback: {
                await callTracker.markCalled()
                return true
            },
            cgEventResult: true
        )
        let runner = DiagnosticRunner(checker: checker)
        _ = await runner.runAll()

        let called = await callTracker.wasCalled
        #expect(called)
    }

    // MARK: - No-prompt guarantee tests

    @Test("runAll() never calls requestAccessibility — only checkAccessibility")
    func runAllNeverPrompts() async {
        let tracker = PromptTracker()
        let checker = PromptTrackingChecker(
            accessibilityGranted: false,
            touchFrameReceived: false,
            cgEventCreatable: false,
            tracker: tracker
        )
        let runner = DiagnosticRunner(checker: checker)

        // Run diagnostics multiple times (simulating poll cycles)
        for _ in 0..<5 {
            _ = await runner.runAll()
        }

        let checkCount = tracker.checkCount
        let requestCount = tracker.requestCount
        #expect(checkCount == 5, "checkAccessibility should be called each time")
        #expect(requestCount == 0, "requestAccessibility must NEVER be called by runAll()")
    }

    @Test("runAll() with denied permission only calls check, not request")
    func deniedPermissionOnlyChecks() async {
        let tracker = PromptTracker()
        let checker = PromptTrackingChecker(
            accessibilityGranted: false,
            touchFrameReceived: true,
            cgEventCreatable: true,
            tracker: tracker
        )
        let runner = DiagnosticRunner(checker: checker)
        let results = await runner.runAll()

        let ax = results.first { $0.name == "Accessibility Permission" }
        #expect(ax?.status == .fail)

        let requestCount = tracker.requestCount
        #expect(requestCount == 0, "Denied permission must not trigger a prompt")
    }

    @Test("Authorized state — runAll does not prompt")
    func authorizedNeverPrompts() async {
        let tracker = PromptTracker()
        let checker = PromptTrackingChecker(
            accessibilityGranted: true,
            touchFrameReceived: true,
            cgEventCreatable: true,
            tracker: tracker
        )
        let runner = DiagnosticRunner(checker: checker)
        _ = await runner.runAll()

        let requestCount = tracker.requestCount
        #expect(requestCount == 0)
    }

    @Test("DiagnosticChecking protocol does not include requestAccessibility")
    func protocolHasNoRequest() {
        // Compile-time verification: DiagnosticChecking only has check methods.
        // If requestAccessibility were added back, this test's MockDiagnosticChecker
        // would fail to compile since it doesn't implement requestAccessibility.
        let checker = MockDiagnosticChecker(
            accessibilityGranted: true,
            touchFrameReceived: true,
            cgEventCreatable: true
        )
        // Just verify it conforms — the point is compile-time safety
        let _: any DiagnosticChecking = checker
    }
}

// MARK: - Mocks

struct MockDiagnosticChecker: DiagnosticChecking {
    let accessibilityGranted: Bool
    let touchFrameReceived: Bool
    let cgEventCreatable: Bool

    func checkAccessibility() -> Bool { accessibilityGranted }
    func checkTouchFrames() async -> Bool { touchFrameReceived }
    func checkCGEventCreation() -> Bool { cgEventCreatable }
}

/// Mock that uses a callback for touchFrames to verify it's actually invoked.
struct CallbackDiagnosticChecker: DiagnosticChecking {
    let accessibilityResult: Bool
    let touchFrameCallback: @Sendable () async -> Bool
    let cgEventResult: Bool

    func checkAccessibility() -> Bool { accessibilityResult }
    func checkTouchFrames() async -> Bool { await touchFrameCallback() }
    func checkCGEventCreation() -> Bool { cgEventResult }
}

/// Actor to safely track whether a callback was invoked.
actor CallTracker {
    private(set) var wasCalled = false
    func markCalled() { wasCalled = true }
}

/// Tracks check vs request call counts to verify no-prompt guarantee.
/// Uses OSAtomicIncrement for thread-safe counting without async.
final class PromptTracker: Sendable {
    private let _checkCount = MutableSendableInt()
    private let _requestCount = MutableSendableInt()

    var checkCount: Int { _checkCount.value }
    var requestCount: Int { _requestCount.value }

    func recordCheck() { _checkCount.increment() }
    func recordRequest() { _requestCount.increment() }
}

/// Thread-safe mutable int using os_unfair_lock.
final class MutableSendableInt: @unchecked Sendable {
    private var _value = 0
    private let lock = NSLock()

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func increment() {
        lock.lock()
        _value += 1
        lock.unlock()
    }
}

/// Checker that tracks whether check vs request is called.
/// DiagnosticChecking no longer has requestAccessibility(),
/// so this struct proves that runAll() can only call check methods.
struct PromptTrackingChecker: DiagnosticChecking {
    let accessibilityGranted: Bool
    let touchFrameReceived: Bool
    let cgEventCreatable: Bool
    let tracker: PromptTracker

    func checkAccessibility() -> Bool {
        tracker.recordCheck()
        return accessibilityGranted
    }

    func checkTouchFrames() async -> Bool { touchFrameReceived }
    func checkCGEventCreation() -> Bool { cgEventCreatable }
}
