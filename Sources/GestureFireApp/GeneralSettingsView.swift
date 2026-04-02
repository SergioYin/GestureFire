import GestureFireEngine
import GestureFireTypes
import SwiftUI

struct GeneralSettingsView: View {
    let coordinator: AppCoordinator

    @State private var launchAtLoginError: String?

    private var config: GestureFireConfig {
        coordinator.configStore.config
    }

    var body: some View {
        Form {
            Section("Sound Feedback") {
                Toggle("Play sound on gesture recognition", isOn: Binding(
                    get: { config.soundEnabled },
                    set: { newValue in
                        coordinator.configStore.update { $0.soundEnabled = newValue }
                        coordinator.soundFeedback.update(from: coordinator.configStore.config)
                    }
                ))

                if config.soundEnabled {
                    HStack {
                        Text("Volume")
                        Slider(
                            value: Binding(
                                get: { config.soundVolume },
                                set: { newValue in
                                    coordinator.configStore.update { $0.soundVolume = newValue }
                                    coordinator.soundFeedback.update(from: coordinator.configStore.config)
                                }
                            ),
                            in: 0...1
                        )
                        Text("\(Int(config.soundVolume * 100))%")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }

            Section("Status Panel") {
                Toggle("Show floating panel on gesture recognition", isOn: Binding(
                    get: { config.statusPanelEnabled },
                    set: { newValue in
                        coordinator.configStore.update { $0.statusPanelEnabled = newValue }
                    }
                ))
            }

            Section("System") {
                Toggle("Launch at login", isOn: Binding(
                    get: { config.launchAtLogin },
                    set: { newValue in
                        let manager = LaunchAtLoginManager()
                        if let error = manager.sync(with: newValue) {
                            launchAtLoginError = error
                        } else {
                            coordinator.configStore.update { $0.launchAtLogin = newValue }
                            launchAtLoginError = nil
                        }
                    }
                ))

                if let error = launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                let status = LaunchAtLoginManager().status
                if status == .requiresApproval {
                    Text("Launch at login requires approval in System Settings → General → Login Items")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}
