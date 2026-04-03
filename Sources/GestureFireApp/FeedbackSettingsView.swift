import GestureFireEngine
import GestureFireTypes
import SwiftUI

struct FeedbackSettingsView: View {
    let coordinator: AppCoordinator

    @State private var launchAtLoginError: String?
    @State private var launchAtLoginStatus: LaunchAtLoginManager.Status = .notRegistered

    private var config: GestureFireConfig {
        coordinator.configStore.config
    }

    private let loginManager = LaunchAtLoginManager()

    var body: some View {
        Form {
            Section("Recognition Feedback") {
                Toggle("Play sound on gesture recognition", isOn: Binding(
                    get: { config.soundEnabled },
                    set: { newValue in
                        coordinator.configStore.update { $0.soundEnabled = newValue }
                        coordinator.soundFeedback.update(from: coordinator.configStore.config)
                    }
                ))

                if config.soundEnabled {
                    LabeledContent("Volume") {
                        HStack {
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
                        if let error = loginManager.sync(with: newValue) {
                            launchAtLoginError = error
                        } else {
                            coordinator.configStore.update { $0.launchAtLogin = newValue }
                            launchAtLoginError = nil
                        }
                        launchAtLoginStatus = loginManager.status
                    }
                ))

                if let error = launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if launchAtLoginStatus == .requiresApproval {
                    Text("Launch at login requires approval in System Settings → General → Login Items")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .onAppear {
            launchAtLoginStatus = loginManager.status
        }
    }
}
