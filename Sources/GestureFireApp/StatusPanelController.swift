import AppKit
import GestureFireEngine
import GestureFireTypes
import SwiftUI

/// Manages a floating, non-activating NSPanel for gesture feedback.
/// The panel appears briefly on recognition, then auto-dismisses.
/// Key requirements:
///   - Does NOT steal focus from the current app
///   - Does NOT block keyboard input
///   - Floats above other windows
///   - Auto-dismisses after a configurable duration
@MainActor
final class StatusPanelController {
    static let shared = StatusPanelController()

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var dismissDelay: Duration = .seconds(3)

    /// Show the status panel with gesture feedback.
    /// Only call for `.recognized` and `.shortcutFired` events (per Phase 2 trigger policy).
    func show(event: PipelineEvent) {
        dismissTask?.cancel()

        let panel = getOrCreatePanel()
        panel.contentView = NSHostingView(rootView: StatusPanelView(event: event))

        // Position near top-right of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = CGSize(width: 280, height: 60)
            let origin = CGPoint(
                x: screenFrame.maxX - panelSize.width - 16,
                y: screenFrame.maxY - panelSize.height - 8
            )
            panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
        }

        panel.orderFrontRegardless()

        // Schedule auto-dismiss
        dismissTask = Task {
            try? await Task.sleep(for: dismissDelay)
            guard !Task.isCancelled else { return }
            self.hide()
        }
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
    }

    private func getOrCreatePanel() -> NSPanel {
        if let existing = panel { return existing }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 60),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isReleasedWhenClosed = false
        // Non-activating: does not become key or main window
        p.becomesKeyOnlyIfNeeded = true
        p.hidesOnDeactivate = false
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true

        self.panel = p
        return p
    }
}
