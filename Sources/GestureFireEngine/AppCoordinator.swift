import ApplicationServices
import Foundation
import GestureFireConfig
import GestureFireIntegration
import GestureFireRecognition
import GestureFireShortcuts
import GestureFireTypes
import Observation
import os

/// Main coordinator connecting all components.
/// @MainActor because it manages UI state and coordinates with ConfigStore.
@MainActor
@Observable
public final class AppCoordinator {
    public let configStore: ConfigStore
    public private(set) var engineState: EngineState = .disabled
    public private(set) var gestureCount = 0
    public private(set) var lastGesture: GestureType?

    /// Last event in the gesture pipeline — for diagnostics observability.
    public private(set) var lastPipelineEvent: PipelineEvent?

    /// Recent pipeline events (ring buffer, last 20).
    public private(set) var recentEvents: [PipelineEvent] = []

    /// Coordinator-level flag: has ANY touchSource ever received a frame this session?
    /// Survives stop/restart cycles — reset only on app relaunch.
    public private(set) var hasEverReceivedFrame = false

    @ObservationIgnored private var recognitionLoop: RecognitionLoop
    @ObservationIgnored private var touchSource: OMSTouchSource?
    @ObservationIgnored private let fileLogger: FileLogger
    @ObservationIgnored private var permissionPollTask: Task<Void, Never>?
    @ObservationIgnored private var startingTimeoutTask: Task<Void, Never>?

    /// Guards against repeated permission prompts within one start cycle.
    @ObservationIgnored private var hasPromptedThisCycle = false

    /// Tracks last reported finger count to avoid flooding pipeline with duplicate events.
    @ObservationIgnored private var lastReportedFingerCount = 0

    public init(
        configStore: ConfigStore = ConfigStore(),
        fileLogger: FileLogger = FileLogger()
    ) {
        self.configStore = configStore
        self.fileLogger = fileLogger
        self.recognitionLoop = RecognitionLoop(sensitivity: configStore.config.sensitivity)
    }

    // MARK: - Start / Stop

    public func start() {
        // Guard: don't restart if already running or starting
        if case .running = engineState { return }
        if case .starting = engineState { return }

        hasPromptedThisCycle = false

        // Pure read — no system dialog
        if AXIsProcessTrusted() {
            beginListening()
            return
        }

        // Not authorized: prompt once, then poll
        hasPromptedThisCycle = true
        _ = requestAccessibilityPrompt()
        Logger.engine.info("Accessibility prompt shown")

        // Re-check immediately in case it was already granted
        if AXIsProcessTrusted() {
            beginListening()
            return
        }

        engineState = .needsPermission
        startPermissionPolling()
    }

    public func stop() {
        permissionPollTask?.cancel()
        permissionPollTask = nil
        startingTimeoutTask?.cancel()
        startingTimeoutTask = nil
        if let source = touchSource {
            Task { await source.stop() }
        }
        touchSource = nil
        engineState = .disabled
        hasPromptedThisCycle = false
        Logger.engine.info("GestureFire stopped")
    }

    public func toggle() {
        if engineState == .disabled || engineState == .needsPermission {
            start()
        } else {
            stop()
        }
    }

    /// Retry starting after permission was granted or error resolved.
    public func retry() {
        stop()
        start()
    }

    // MARK: - Permission (explicit user action only)

    /// Show system accessibility permission prompt.
    /// Must ONLY be called from explicit user button taps.
    public func requestAccessibilityPermission() {
        _ = requestAccessibilityPrompt()
        Logger.engine.info("User-initiated accessibility prompt")
    }

    // MARK: - Diagnostics

    /// Run Layer 1 diagnostics with real state.
    /// Pure observation — never triggers system prompts.
    public func runDiagnostics() async -> [DiagnosticResult] {
        // Use coordinator-level flag, not per-instance OMSTouchSource flag
        let everReceived = hasEverReceivedFrame
        let checker = SystemDiagnosticChecker(touchFrameChecker: {
            everReceived
        })
        let runner = DiagnosticRunner(checker: checker)
        return await runner.runAll()
    }

    /// Whether touch frames have been received (for diagnostics).
    /// Uses coordinator-level flag that survives stop/restart cycles.
    public var hasTouchFrames: Bool {
        hasEverReceivedFrame
    }

    /// Update recognizer sensitivity from current config.
    public func reloadSensitivity() async {
        let sensitivity = configStore.config.sensitivity
        await recognitionLoop.updateSensitivity(sensitivity)
    }

    // MARK: - Onboarding

    /// Whether the user has not yet completed the onboarding wizard.
    public var needsOnboarding: Bool {
        !configStore.config.hasCompletedOnboarding
    }

    /// The active onboarding coordinator, if onboarding is in progress.
    public private(set) var onboardingCoordinator: OnboardingCoordinator?

    /// Optional sample recorder for calibration — coordinator feeds frames to it.
    @ObservationIgnored public private(set) var sampleRecorder: SampleRecorder?

    /// Begin the onboarding flow. Creates coordinator + recorder.
    public func beginOnboarding() {
        let recorder = SampleRecorder(sensitivity: configStore.config.sensitivity)
        self.sampleRecorder = recorder
        let coordinator = OnboardingCoordinator(
            configStore: configStore,
            sampleRecorder: recorder,
            engineDelegate: self
        )

        // For returning users: load existing config state
        let config = configStore.config
        if config.hasCompletedOnboarding {
            // Match existing gestures to a known preset, or use custom
            let existingGestures = config.gestures
            if let matched = GesturePreset.allPresets.first(where: {
                !$0.gestures.isEmpty && $0.gestures == existingGestures
            }) {
                coordinator.selectPreset(matched)
            } else if !existingGestures.isEmpty {
                // Custom mappings — create an ad-hoc preset reflecting current config
                coordinator.selectPreset(GesturePreset(
                    id: "custom",
                    displayName: "Custom",
                    description: "Your current mappings",
                    icon: "slider.horizontal.3",
                    gestures: existingGestures
                ))
            }

            // Skip permission step if already granted
            if AXIsProcessTrusted() {
                coordinator.goToStep(.preset)
            }
        }

        self.onboardingCoordinator = coordinator
        Logger.engine.info("Onboarding started")
    }

    /// End the onboarding flow. Nils out coordinator + recorder.
    public func finishOnboarding() {
        onboardingCoordinator = nil
        sampleRecorder = nil
        Logger.engine.info("Onboarding finished")
    }

    // MARK: - Private — Startup

    private func beginListening() {
        engineState = .starting
        // Clear stale pipeline events from previous cycle to avoid contradictions
        recentEvents.removeAll()
        lastPipelineEvent = nil
        lastReportedFingerCount = 0
        Logger.engine.info("GestureFire starting...")

        let source = OMSTouchSource { [weak self] frame in
            guard let self else { return }
            Task { @MainActor in
                await self.handleFrame(frame)
            }
        }
        touchSource = source
        Task { await source.start() }

        // Transition to .running once we receive the first frame,
        // or timeout after 10 seconds.
        startingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                if case .starting = self.engineState {
                    self.engineState = .failed("No touch frames received — is a trackpad connected?")
                }
            }
        }

        // Cleanup old logs
        try? fileLogger.cleanup()
    }

    /// Polls accessibility status every 2s using AXIsProcessTrusted() (read-only).
    /// Never shows a system dialog.
    private func startPermissionPolling() {
        permissionPollTask?.cancel()
        permissionPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { break }
                // Pure read — no prompt
                if AXIsProcessTrusted() {
                    await MainActor.run {
                        Logger.engine.info("Accessibility permission granted — starting engine")
                        self.beginListening()
                    }
                    break
                }
            }
        }
    }

    // MARK: - Private — Frame handling

    private func handleFrame(_ frame: TouchFrame) async {
        // Feed frame to sample recorder via onboarding coordinator if active
        onboardingCoordinator?.feedFrameToRecorder(frame)

        // Transition from .starting → .running on first frame
        if case .starting = engineState {
            engineState = .running
            hasEverReceivedFrame = true
            startingTimeoutTask?.cancel()
            startingTimeoutTask = nil
            Logger.engine.info("GestureFire running — first touch frame received")
        }

        guard engineState.isOperational else { return }

        // Count all active fingers (any state except notTouching/leaving)
        let activeCount = frame.points.filter { $0.state != .notTouching && $0.state != .leaving }.count
        // Only record frame event when finger count changes — avoids flooding
        if activeCount != lastReportedFingerCount {
            lastReportedFingerCount = activeCount
            if activeCount > 0 {
                let states = frame.points
                    .filter { $0.state != .notTouching && $0.state != .leaving }
                    .map { "\($0.state.rawValue)" }
                    .joined(separator: ", ")
                recordEvent(.frameReceived(fingerCount: activeCount, timestamp: Date(),
                                           detail: states))
            }
        }

        let result = await recognitionLoop.processFrame(frame)

        // Record rejections (only meaningful ones, not empty)
        if !result.allRejections.isEmpty {
            let reason = result.allRejections.first?.label ?? "unknown"
            recordEvent(.rejected(reason: reason, timestamp: Date()))
        }

        guard let gesture = result.gesture else { return }

        gestureCount += 1
        lastGesture = gesture

        // During calibration, only record the gesture — don't fire shortcuts.
        // Firing shortcuts (e.g. Cmd+W) during practice would close windows.
        let isCalibrating = onboardingCoordinator?.isCalibrating == true

        let shortcut = configStore.config.shortcut(for: gesture)

        if let shortcut, !isCalibrating {
            // Fire keyboard shortcut
            let success = KeyboardSimulator.fire(shortcut)
            if success {
                recordEvent(.shortcutFired(gesture: gesture, shortcut: shortcut.stringValue, timestamp: Date()))
            } else {
                recordEvent(.shortcutFailed(gesture: gesture, shortcut: shortcut.stringValue, timestamp: Date()))
            }
            Logger.recognition.info("Recognized: \(gesture.rawValue) → \(shortcut.stringValue) (fired: \(success))")
        } else if isCalibrating {
            recordEvent(.recognized(gesture: gesture, timestamp: Date()))
            Logger.recognition.info("Recognized (calibration): \(gesture.rawValue) — shortcut suppressed")
        } else {
            recordEvent(.unmapped(gesture: gesture, timestamp: Date()))
            Logger.recognition.info("Recognized: \(gesture.rawValue) → (unmapped)")
        }

        // Log to file
        let entry = LogEntry(
            timestamp: Date(),
            gesture: gesture,
            shortcut: shortcut?.stringValue ?? "",
            recognized: true
        )
        do {
            try fileLogger.log(entry)
        } catch {
            Logger.engine.warning("Failed to write log: \(error)")
        }
    }

    private func recordEvent(_ event: PipelineEvent) {
        lastPipelineEvent = event
        recentEvents.append(event)
        if recentEvents.count > 20 {
            recentEvents.removeFirst(recentEvents.count - 20)
        }
    }
}

// MARK: - OnboardingEngineDelegate

extension AppCoordinator: OnboardingEngineDelegate {
    public func startEngine() {
        start()
    }

    public func stopEngine() {
        stop()
    }
}
