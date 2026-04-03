import GestureFireEngine
import GestureFireTypes
import SwiftUI

struct MenuBarView: View {
    let coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Consolidated status line
        HStack(spacing: 4) {
            Image(systemName: coordinator.engineState.systemImage)
            Text(statusText)
        }
        .font(.caption)

        Divider()

        // Single toggle button
        switch coordinator.engineState {
        case .disabled, .failed:
            Button("Enable") { coordinator.start() }
        case .needsPermission:
            Button("Grant Permission & Enable") { coordinator.start() }
        case .starting:
            Button("Starting...") {}
                .disabled(true)
        case .running:
            Button("Disable") { coordinator.stop() }
        }

        // Retry for failed/needsPermission
        if case .failed = coordinator.engineState {
            Button("Retry") { coordinator.retry() }
        }
        if case .needsPermission = coordinator.engineState {
            Button("Retry") { coordinator.retry() }
        }

        Divider()

        Button("Settings...") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Button("Reconfigure Gestures...") {
            coordinator.beginOnboarding()
            OnboardingWindowController.shared.showDeferred(coordinator: coordinator)
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var statusText: String {
        switch coordinator.engineState {
        case .running:
            let count = coordinator.gestureCount
            return count > 0 ? "\(coordinator.engineState.displayLabel) · \(count) gestures" : coordinator.engineState.displayLabel
        default:
            return coordinator.engineState.displayLabel
        }
    }
}
