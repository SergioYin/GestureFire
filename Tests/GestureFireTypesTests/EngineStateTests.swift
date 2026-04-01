import Testing
@testable import GestureFireTypes

@Suite("EngineState")
struct EngineStateTests {

    @Test("isOperational only true for .running")
    func isOperational() {
        #expect(EngineState.disabled.isOperational == false)
        #expect(EngineState.needsPermission.isOperational == false)
        #expect(EngineState.starting.isOperational == false)
        #expect(EngineState.running.isOperational == true)
        #expect(EngineState.failed("reason").isOperational == false)
    }

    @Test("displayLabel is non-empty for all states")
    func displayLabels() {
        let states: [EngineState] = [.disabled, .needsPermission, .starting, .running, .failed("test")]
        for state in states {
            #expect(!state.displayLabel.isEmpty)
        }
    }

    @Test("systemImage is non-empty for all states")
    func systemImages() {
        let states: [EngineState] = [.disabled, .needsPermission, .starting, .running, .failed("test")]
        for state in states {
            #expect(!state.systemImage.isEmpty)
        }
    }

    @Test("failed state includes reason in displayLabel")
    func failedReason() {
        let state = EngineState.failed("no trackpad")
        #expect(state.displayLabel.contains("no trackpad"))
    }
}
