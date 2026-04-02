import AppKit
import GestureFireEngine
import GestureFireTypes
import SwiftUI

/// Observable view model so the panel content updates in-place
/// without replacing the NSHostingView (which triggers window server operations).
@MainActor
@Observable
final class StatusPanelViewModel {
    var event: PipelineEvent?
    var isVisible: Bool = false
}

/// Manages a floating, non-activating NSPanel for gesture feedback.
/// The panel appears briefly on recognition, then auto-dismisses.
///
/// Design: the NSHostingView and SwiftUI view are created ONCE.
/// Content updates flow through `StatusPanelViewModel` — no view replacement,
/// no repeated `orderFrontRegardless()` calls, eliminating macOS system sounds.
@MainActor
final class StatusPanelController {
    static let shared = StatusPanelController()

    private var panel: NSPanel?
    private var viewModel = StatusPanelViewModel()
    private var dismissTask: Task<Void, Never>?
    private var dismissDelay: Duration = .seconds(3)
    private var hasPositioned = false

    /// Show the status panel with gesture feedback.
    /// Only call for `.recognized` and `.shortcutFired` events (per Phase 2 trigger policy).
    func show(event: PipelineEvent) {
        dismissTask?.cancel()

        // Update the view model — SwiftUI reacts without replacing the hosting view
        viewModel.event = event
        viewModel.isVisible = true

        let panel = getOrCreatePanel()

        // Position on first show only
        if !hasPositioned, let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = CGSize(width: 280, height: 60)
            let origin = CGPoint(
                x: screenFrame.maxX - panelSize.width - 16,
                y: screenFrame.maxY - panelSize.height - 8
            )
            panel.setFrame(NSRect(origin: origin, size: panelSize), display: false)
            hasPositioned = true
        }

        // Show panel — use alphaValue to avoid repeated orderFrontRegardless calls
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        panel.alphaValue = 1

        // Schedule auto-dismiss
        dismissTask = Task { [weak self] in
            do {
                try await Task.sleep(for: self?.dismissDelay ?? .seconds(3))
                self?.hide()
            } catch {
                // Cancelled — nothing to do
            }
        }
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        viewModel.isVisible = false
        // Use alphaValue instead of orderOut to avoid window server sound triggers
        panel?.alphaValue = 0
        panel?.orderOut(nil)
    }

    private func getOrCreatePanel() -> NSPanel {
        if let existing = panel { return existing }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 60),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true  // defer creation until actually needed
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
        // Suppress window appearance animation and any associated system sound effects.
        p.animationBehavior = .none
        p.alphaValue = 0

        // Create the hosting view ONCE with the shared view model
        let hostingView = NSHostingView(rootView: StatusPanelContentView(viewModel: viewModel))
        p.contentView = hostingView

        self.panel = p
        return p
    }
}

/// Wrapper view that observes the view model for content updates.
/// This view is created once and updates reactively — no NSHostingView replacement needed.
private struct StatusPanelContentView: View {
    @Bindable var viewModel: StatusPanelViewModel

    var body: some View {
        Group {
            if let event = viewModel.event {
                StatusPanelView(event: event)
            }
        }
    }
}
