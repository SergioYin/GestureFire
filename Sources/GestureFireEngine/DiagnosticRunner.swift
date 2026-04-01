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
/// All methods are read-only checks — none may trigger system prompts.
public protocol DiagnosticChecking: Sendable {
    /// Read current accessibility trust status. Must NOT trigger any system UI.
    func checkAccessibility() -> Bool
    func checkTouchFrames() async -> Bool
    func checkCGEventCreation() -> Bool
}

/// Runs Layer 1 diagnostics (auto-detectable checks).
/// Pure read-only — never triggers system permission prompts.
/// Layer 2 (user confirmation) is handled in UI.
public struct DiagnosticRunner: Sendable {
    private let checker: any DiagnosticChecking

    public init(checker: any DiagnosticChecking = SystemDiagnosticChecker()) {
        self.checker = checker
    }

    /// Run all Layer 1 diagnostic checks.
    /// This is pure observation — it will NOT show any system dialogs.
    public func runAll() async -> [DiagnosticResult] {
        var results: [DiagnosticResult] = []

        // 1. Accessibility permission — check only, never prompt
        let axOK = checker.checkAccessibility()
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
/// All methods are read-only — none trigger system permission prompts.
public struct SystemDiagnosticChecker: DiagnosticChecking, Sendable {
    private let touchFrameChecker: @Sendable () async -> Bool

    public init(touchFrameChecker: @escaping @Sendable () async -> Bool = { false }) {
        self.touchFrameChecker = touchFrameChecker
    }

    public func checkAccessibility() -> Bool {
        // AXIsProcessTrusted() is a pure read — no system UI.
        AXIsProcessTrusted()
    }

    public func checkTouchFrames() async -> Bool {
        await touchFrameChecker()
    }

    public func checkCGEventCreation() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        return event != nil
    }
}

/// Standalone function for requesting accessibility permission.
/// Shows the system prompt dialog. Must ONLY be called from explicit user actions.
/// Returns true if permission is already granted (no prompt shown).
public func requestAccessibilityPrompt() -> Bool {
    let key = "AXTrustedCheckOptionPrompt" as CFString
    let options = [key: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}
