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
}

/// NSPanel subclass that never becomes key or main window.
/// Prevents all window-activation-related system sounds.
final class SilentPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Manages a floating, non-activating NSPanel for gesture feedback.
/// The panel appears briefly on recognition, then auto-dismisses.
///
/// Sound-suppression design (validated Phase 2.5, hardened Phase 2.6):
/// 1. SilentPanel subclass blocks key/main promotion — no activation sounds
/// 2. Panel is ordered front ONCE at creation, then stays in window list forever
/// 3. Show/hide uses only alphaValue — no orderFront/orderOut after creation
/// 4. NSHostingView created once, content updates via @Observable view model
/// 5. animationBehavior = .none suppresses window appearance animation sounds
@MainActor
final class StatusPanelController {
    static let shared = StatusPanelController()

    private var panel: SilentPanel?
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

        // No orderFront here — panel was ordered front at creation time.
        // Just toggle alpha to make it visible.
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
        // Only alpha change — no orderOut, no window server operations.
        panel?.alphaValue = 0
    }

    private func getOrCreatePanel() -> SilentPanel {
        if let existing = panel { return existing }

        let p = SilentPanel(
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
        p.becomesKeyOnlyIfNeeded = true
        p.hidesOnDeactivate = false
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.animationBehavior = .none

        // Create the hosting view ONCE with the shared view model
        let hostingView = NSHostingView(rootView: StatusPanelContentView(viewModel: viewModel))
        p.contentView = hostingView

        // Order front exactly once, at alpha 0. After this, show/hide
        // uses only alphaValue — zero window server operations in the
        // show/hide cycle, which eliminates all system sound triggers.
        p.alphaValue = 0
        p.orderFrontRegardless()

        self.panel = p
        return p
    }
}

/// Wrapper view that observes the view model for content updates.
/// This view is created once and updates reactively — no NSHostingView replacement needed.
private struct StatusPanelContentView: View {
    @Bindable var viewModel: StatusPanelViewModel

    var body: some View {
        if let event = viewModel.event {
            StatusPanelView(event: event)
        }
    }
}
