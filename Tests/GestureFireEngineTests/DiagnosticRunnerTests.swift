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
}

// MARK: - Mock

struct MockDiagnosticChecker: DiagnosticChecking {
    let accessibilityGranted: Bool
    let touchFrameReceived: Bool
    let cgEventCreatable: Bool

    func checkAccessibility() -> Bool { accessibilityGranted }
    func checkTouchFrames() async -> Bool { touchFrameReceived }
    func checkCGEventCreation() -> Bool { cgEventCreatable }
}
