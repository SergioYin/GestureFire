import CoreGraphics
import Foundation
import os

/// Monitors keyboard activity and reports whether gesture recognition
/// should be suppressed due to recent typing.
///
/// Installs a passive (listen-only) CGEventTap on the main run loop.
/// Requires Accessibility permission, which GestureFire already holds.
public actor TypingMonitor {
    private var lastKeystrokeAt: Date?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    public private(set) var isRunning = false

    private static let logger = Logger(subsystem: "com.gesturefire", category: "typingMonitor")

    public init() {}

    /// Install the event tap. Safe to call when already running (no-op).
    public func start() {
        guard !isRunning else { return }
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: TypingMonitor.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap else {
            Self.logger.warning("CGEventTap creation failed — palm rejection unavailable (check Accessibility permission)")
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.eventTap = tap
        self.runLoopSource = source
        self.isRunning = true
        Self.logger.info("TypingMonitor started")
    }

    /// Remove the event tap. Safe to call when not running (no-op).
    public func stop() {
        guard isRunning else { return }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        lastKeystrokeAt = nil
        Self.logger.info("TypingMonitor stopped")
    }

    /// Returns true if a keystroke occurred within the last `windowMs` milliseconds.
    public func isTypingSuppressed(windowMs: Double) -> Bool {
        guard let last = lastKeystrokeAt else { return false }
        return Date().timeIntervalSince(last) * 1_000 < windowMs
    }

    fileprivate func recordKeystroke() {
        lastKeystrokeAt = Date()
    }

    // CGEventTap C callback — bridges into the actor via an async Task.
    // passUnretained is safe: AppCoordinator owns the monitor for its full lifetime.
    private static let eventTapCallback: CGEventTapCallBack = { _, _, event, userInfo in
        guard let userInfo else { return Unmanaged.passRetained(event) }
        let monitor = Unmanaged<TypingMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        Task { await monitor.recordKeystroke() }
        return Unmanaged.passRetained(event)
    }
}
