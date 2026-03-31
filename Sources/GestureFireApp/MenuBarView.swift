import GestureFireEngine
import SwiftUI

struct MenuBarView: View {
    let coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(coordinator.isEnabled ? "Disable" : "Enable") {
            coordinator.toggle()
        }

        Divider()

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

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
