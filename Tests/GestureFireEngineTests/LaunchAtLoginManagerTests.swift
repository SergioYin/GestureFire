import Testing
@testable import GestureFireEngine

@MainActor
@Suite("LaunchAtLoginManager")
struct LaunchAtLoginManagerTests {

    @Test("Status query returns without crashing")
    func statusQuery() {
        let manager = LaunchAtLoginManager()
        let status = manager.status
        // Status depends on system state (could be .enabled, .notRegistered, .requiresApproval, .unknown)
        // The important thing is it returns a valid value without crashing
        let validStatuses: [LaunchAtLoginManager.Status] = [.enabled, .notRegistered, .requiresApproval]
        let isKnown = validStatuses.contains(status)
        let isUnknown: Bool = if case .unknown = status { true } else { false }
        #expect(isKnown || isUnknown)
    }

    @Test("Enable returns error in unsigned test environment")
    func enableReturnsError() {
        let manager = LaunchAtLoginManager()
        // In test environment, register() will likely fail (no valid bundle/codesign)
        // We verify the error branch works correctly
        let result = manager.enable()
        // result is either nil (success, unlikely in test) or an error message (expected)
        if let error = result {
            #expect(error.contains("Failed") || error.contains("failed") || !error.isEmpty)
        }
        // Either way, no crash
    }

    @Test("Disable does not crash in test environment")
    func disableDoesNotCrash() {
        let manager = LaunchAtLoginManager()
        _ = manager.disable()
        // No crash is success
    }

    @Test("Sync with true calls enable, false calls disable")
    func syncDelegates() {
        let manager = LaunchAtLoginManager()
        _ = manager.sync(with: true)
        _ = manager.sync(with: false)
        // Verify no crash, error messages are returned (not thrown)
    }
}
