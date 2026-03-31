import Foundation
import GestureFireConfig
import GestureFireIntegration
import GestureFireRecognition
import GestureFireShortcuts
import GestureFireTypes
import os

/// Main coordinator connecting all components.
/// @MainActor because it manages UI state and coordinates with ConfigStore.
@MainActor
public final class AppCoordinator: Observable {
    public let configStore: ConfigStore
    public private(set) var isEnabled = false
    public private(set) var gestureCount = 0
    public private(set) var lastGesture: GestureType?

    private var recognitionLoop: RecognitionLoop
    private var touchSource: OMSTouchSource?
    private let fileLogger: FileLogger
    private let diagnosticRunner: DiagnosticRunner

    public init(
        configStore: ConfigStore = ConfigStore(),
        fileLogger: FileLogger = FileLogger(),
        diagnosticRunner: DiagnosticRunner = DiagnosticRunner()
    ) {
        self.configStore = configStore
        self.fileLogger = fileLogger
        self.diagnosticRunner = diagnosticRunner
        self.recognitionLoop = RecognitionLoop(sensitivity: configStore.config.sensitivity)
    }

    public func start() {
        isEnabled = true
        touchSource = OMSTouchSource { [weak self] frame in
            guard let self else { return }
            Task { @MainActor in
                await self.handleFrame(frame)
            }
        }
        touchSource?.start()
        Logger.engine.info("GestureFire started")

        // Cleanup old logs on startup
        try? fileLogger.cleanup()
    }

    public func stop() {
        isEnabled = false
        touchSource?.stop()
        touchSource = nil
        Logger.engine.info("GestureFire stopped")
    }

    public func toggle() {
        if isEnabled { stop() } else { start() }
    }

    /// Run Layer 1 diagnostics.
    public func runDiagnostics() async -> [DiagnosticResult] {
        await diagnosticRunner.runAll()
    }

    /// Whether touch frames have been received (for diagnostics).
    public var hasTouchFrames: Bool {
        touchSource?.hasReceivedFrame ?? false
    }

    /// Update recognizer sensitivity from current config.
    public func reloadSensitivity() async {
        let sensitivity = configStore.config.sensitivity
        await recognitionLoop.updateSensitivity(sensitivity)
    }

    // MARK: - Private

    private func handleFrame(_ frame: TouchFrame) async {
        guard isEnabled else { return }

        let result = await recognitionLoop.processFrame(frame)
        guard let gesture = result.gesture else { return }

        gestureCount += 1
        lastGesture = gesture

        let shortcut = configStore.config.shortcut(for: gesture)
        Logger.recognition.info("Recognized: \(gesture.rawValue) → \(shortcut?.stringValue ?? "(unmapped)")")

        // Fire keyboard shortcut
        if let shortcut {
            KeyboardSimulator.fire(shortcut)
        }

        // Log
        let entry = LogEntry(
            timestamp: Date(),
            gesture: gesture,
            shortcut: shortcut?.stringValue ?? "",
            recognized: true
        )
        try? fileLogger.log(entry)
    }
}
