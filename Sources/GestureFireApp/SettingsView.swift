import GestureFireConfig
import GestureFireEngine
import GestureFireTypes
import SwiftUI

struct SettingsView: View {
    let coordinator: AppCoordinator

    var body: some View {
        TabView {
            GestureMappingView(coordinator: coordinator)
                .tabItem { Label("Gestures", systemImage: "hand.tap") }

            SensitivityView(coordinator: coordinator)
                .tabItem { Label("Sensitivity", systemImage: "slider.horizontal.3") }
        }
        .padding()
    }
}

// MARK: - Gesture Mapping

struct GestureMappingView: View {
    let coordinator: AppCoordinator
    var body: some View {
        Form {
            Section("TipTap Gestures") {
                ForEach(GestureType.allCases, id: \.self) { gesture in
                    HStack {
                        Text(gesture.displayName)
                            .frame(width: 120, alignment: .leading)
                        ShortcutField(
                            shortcut: coordinator.configStore.config.shortcut(for: gesture),
                            onChange: { newShortcut in
                                coordinator.configStore.update { config in
                                    if let shortcut = newShortcut {
                                        config.gestures[gesture.rawValue] = shortcut
                                    } else {
                                        config.gestures.removeValue(forKey: gesture.rawValue)
                                    }
                                }
                            }
                        )
                    }
                }
            }

            Section {
                Text("Tip: Press Enter after typing a shortcut to save it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Shortcut Field

struct ShortcutField: View {
    let shortcut: KeyShortcut?
    let onChange: (KeyShortcut?) -> Void
    @State private var text: String = ""
    @State private var parseError = false

    var body: some View {
        HStack {
            TextField("e.g. cmd+left", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .foregroundColor(parseError ? .red : .primary)
                .onAppear { text = shortcut?.stringValue ?? "" }
                .onSubmit { saveShortcut() }
                .onChange(of: text) { parseError = false }

            if shortcut != nil {
                Button(role: .destructive) {
                    text = ""
                    onChange(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func saveShortcut() {
        if text.isEmpty {
            onChange(nil)
            return
        }
        if let parsed = try? KeyShortcut.parse(text) {
            onChange(parsed)
            text = parsed.stringValue
            parseError = false
        } else {
            parseError = true
        }
    }
}

// MARK: - Sensitivity

struct SensitivityView: View {
    let coordinator: AppCoordinator

    private var sensitivity: SensitivityConfig {
        coordinator.configStore.config.sensitivity
    }

    var body: some View {
        Form {
            Section("TipTap Parameters") {
                parameterRow(.holdThresholdMs, label: "Hold Threshold", unit: "ms")
                parameterRow(.tapMaxDurationMs, label: "Tap Max Duration", unit: "ms")
                parameterRow(.movementTolerance, label: "Movement Tolerance", unit: "")
                parameterRow(.debounceCooldownMs, label: "Cooldown", unit: "ms")
                parameterRow(.directionAngleTolerance, label: "Direction Angle Tolerance", unit: "°")
            }

            Section {
                Button("Reset to Defaults") {
                    coordinator.configStore.update { config in
                        config.sensitivity = .defaults
                    }
                    Task { await coordinator.reloadSensitivity() }
                }
            }
        }
    }

    @ViewBuilder
    private func parameterRow(_ param: SensitivityConfig.Parameter, label: String, unit: String) -> some View {
        let bounds = ParameterBounds.bounds(for: param)
        let value = sensitivity.value(for: param)

        HStack {
            Text(label)
                .frame(width: 180, alignment: .leading)
            Slider(
                value: Binding(
                    get: { value },
                    set: { newValue in
                        coordinator.configStore.update { config in
                            config.sensitivity = config.sensitivity.withValue(newValue, for: param)
                        }
                        Task { await coordinator.reloadSensitivity() }
                    }
                ),
                in: bounds.min...bounds.max
            )
            Text("\(value, specifier: "%.1f")\(unit)")
                .frame(width: 80, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
