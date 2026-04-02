import AppKit
import GestureFireConfig
import GestureFireEngine
import GestureFireTypes
import SwiftUI

/// Shared coordinator accessible to both App and AppDelegate.
@MainActor
private let sharedCoordinator = AppCoordinator()

/// Manages the onboarding window lifecycle.
/// Uses NSWindow (not NSPanel) — panels auto-minimize when the app loses focus.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    /// Show immediately (for AppDelegate at launch).
    func showNow(coordinator: AppCoordinator) {
        presentWindow(coordinator: coordinator)
    }

    /// Show after MenuBarExtra dismiss animation completes.
    func showDeferred(coordinator: AppCoordinator) {
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            presentWindow(coordinator: coordinator)
        }
    }

    /// Bring the window to front if it exists.
    func bringToFront() {
        guard let w = window else { return }
        NSApp.activate(ignoringOtherApps: true)
        w.orderFrontRegardless()
    }

    private func presentWindow(coordinator: AppCoordinator) {
        if let existing = window, existing.isVisible {
            bringToFront()
            return
        }

        // Clean up stale window
        if window != nil {
            window?.delegate = nil
            window?.close()
            window = nil
        }

        guard let onboarding = coordinator.onboardingCoordinator else { return }

        let contentView = OnboardingView(
            coordinator: onboarding,
            appCoordinator: coordinator,
            onDismiss: { [weak self] in
                self?.close()
            }
        )

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Welcome to GestureFire"
        w.contentView = NSHostingView(rootView: contentView)
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self

        self.window = w
        w.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.delegate = nil
        window?.close()
        window = nil
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.window = nil
        }
    }
}

@main
struct GestureFireApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private var coordinator: AppCoordinator { sharedCoordinator }

    var body: some Scene {
        MenuBarExtra("GestureFire", systemImage: coordinator.engineState.systemImage) {
            MenuBarView(coordinator: coordinator)
        }

        Window("GestureFire Settings", id: "settings") {
            SettingsView(coordinator: coordinator)
        }
        .defaultSize(width: 520, height: 500)

        Window("Diagnostics", id: "diagnostics") {
            DiagnosticView(coordinator: coordinator)
        }
        .defaultSize(width: 400, height: 300)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let coordinator = sharedCoordinator

        // Wire status panel to show on recognition events
        coordinator.onStatusEvent = { event in
            guard coordinator.configStore.config.statusPanelEnabled else { return }
            StatusPanelController.shared.show(event: event)
        }

        guard coordinator.needsOnboarding else { return }

        coordinator.beginOnboarding()
        OnboardingWindowController.shared.showNow(coordinator: coordinator)
    }

    /// When the app regains focus (e.g., returning from System Settings after
    /// granting permission), bring the wizard panel back to front automatically.
    @MainActor
    func applicationDidBecomeActive(_ notification: Notification) {
        OnboardingWindowController.shared.bringToFront()
    }
}
