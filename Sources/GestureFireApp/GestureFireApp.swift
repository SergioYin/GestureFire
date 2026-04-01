import AppKit
import GestureFireConfig
import GestureFireEngine
import GestureFireTypes
import SwiftUI

@main
struct GestureFireApp: App {
    @State private var coordinator = AppCoordinator()

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

        Window("Welcome to GestureFire", id: "onboarding") {
            if let onboarding = coordinator.onboardingCoordinator {
                OnboardingView(coordinator: onboarding, appCoordinator: coordinator)
            } else {
                Text("Onboarding not active")
                    .padding()
            }
        }
        .defaultSize(width: 600, height: 480)
    }

    // Onboarding auto-triggered from MenuBarView on first launch
}
