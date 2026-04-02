import GestureFireEngine
import GestureFireTypes
import SwiftUI

struct MenuBarView: View {
    let coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // State display
        HStack(spacing: 4) {
            Image(systemName: coordinator.engineState.systemImage)
            Text(coordinator.engineState.displayLabel)
        }
        .font(.caption)

        // Toggle button — label reflects current state
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
            Button("Retry (after granting permission)") { coordinator.retry() }
        }

        Divider()

        // Last pipeline event
        if let event = coordinator.lastPipelineEvent {
            HStack(spacing: 4) {
                Image(systemName: event.systemImage)
                Text(event.displayDescription)
            }
            .font(.caption)
        }

        if let last = coordinator.lastGesture {
            Text("Last: \(last.displayName)")
                .font(.caption)
        }
        Text("Gestures: \(coordinator.gestureCount)")
            .font(.caption)

        Divider()

        Button("Settings...") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Button("Diagnostics...") {
            openWindow(id: "diagnostics")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Setup Wizard...") {
            coordinator.beginOnboarding()
            OnboardingWindowController.shared.showDeferred(coordinator: coordinator)
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
