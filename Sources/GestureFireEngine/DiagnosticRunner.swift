import ApplicationServices
import CoreGraphics
import Foundation

/// Result of a single diagnostic check.
public struct DiagnosticResult: Sendable {
    public let name: String
    public let status: Status
    public let fixInstruction: String?

    public enum Status: Sendable {
        case pass
        case fail
    }

    public init(name: String, status: Status, fixInstruction: String? = nil) {
        self.name = name
        self.status = status
        self.fixInstruction = fixInstruction
    }
}

/// Protocol for Layer 1 diagnostic checks. Enables mock injection.
public protocol DiagnosticChecking: Sendable {
    func checkAccessibility() -> Bool
    func requestAccessibility() -> Bool
    func checkTouchFrames() async -> Bool
    func checkCGEventCreation() -> Bool
}

/// Runs Layer 1 diagnostics (auto-detectable checks).
/// Layer 2 (user confirmation) is handled in UI.
public struct DiagnosticRunner: Sendable {
    private let checker: any DiagnosticChecking

    public init(checker: any DiagnosticChecking = SystemDiagnosticChecker()) {
        self.checker = checker
    }

    /// Request accessibility permission (shows system prompt if not granted).
    /// Returns true if already granted.
    @discardableResult
    public func requestAccessibility() -> Bool {
        checker.requestAccessibility()
    }

    /// Run all Layer 1 diagnostic checks.
    public func runAll() async -> [DiagnosticResult] {
        var results: [DiagnosticResult] = []

        // 1. Accessibility permission — auto-request if not granted
        var axOK = checker.checkAccessibility()
        if !axOK {
            axOK = checker.requestAccessibility()
        }
        results.append(DiagnosticResult(
            name: "Accessibility Permission",
            status: axOK ? .pass : .fail,
            fixInstruction: axOK ? nil : "System Settings → Privacy & Security → Accessibility → find and enable GestureFire (check the exact executable path)"
        ))

        // 2. Touch frame reception
        let touchOK = await checker.checkTouchFrames()
        results.append(DiagnosticResult(
            name: "Trackpad Touch Frames",
            status: touchOK ? .pass : .fail,
            fixInstruction: touchOK ? nil : "Ensure a trackpad is connected and touch the trackpad to generate frames"
        ))

        // 3. CGEvent creation
        let cgOK = checker.checkCGEventCreation()
        results.append(DiagnosticResult(
            name: "Keyboard Event Creation",
            status: cgOK ? .pass : .fail,
            fixInstruction: cgOK ? nil : "CGEvent creation failed — check Accessibility permission and restart GestureFire"
        ))

        return results
    }
}

/// System-level diagnostic checker using real macOS APIs.
public struct SystemDiagnosticChecker: DiagnosticChecking, Sendable {
    public init() {}

    public func checkAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    public func requestAccessibility() -> Bool {
        // AXIsProcessTrustedWithOptions with prompt=true shows the system dialog
        // asking the user to grant accessibility permission.
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public func checkTouchFrames() async -> Bool {
        // In real usage, OMSManager would set a flag after receiving first frame.
        // For now, return true — actual implementation in AppCoordinator.
        true
    }

    public func checkCGEventCreation() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        return event != nil
    }
}
