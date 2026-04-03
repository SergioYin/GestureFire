import GestureFireConfig
import GestureFireEngine
import GestureFireTypes
import SwiftUI

struct SettingsView: View {
    let coordinator: AppCoordinator

    var body: some View {
        TabView {
            FeedbackSettingsView(coordinator: coordinator)
                .tabItem { Label("Feedback", systemImage: "speaker.wave.2") }

            GestureMappingView(coordinator: coordinator)
                .tabItem { Label("Gestures", systemImage: "hand.tap") }

            AdvancedSettingsView(coordinator: coordinator)
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }

            LogViewerView(coordinator: coordinator)
                .tabItem { Label("Logs", systemImage: "clock") }

            StatusSettingsView(coordinator: coordinator)
                .tabItem { Label("Status", systemImage: "stethoscope") }
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
                Text("Format: Modifier+Key, e.g. cmd+left, ctrl+shift+t")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(GestureType.allCases, id: \.self) { gesture in
                    LabeledContent(gesture.displayName) {
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
        .overlay(alignment: .bottom) {
            if parseError {
                Text("Invalid format. Use Modifier+Key, e.g. cmd+left")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .offset(y: 16)
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
