import GestureFireConfig
import GestureFireEngine
import GestureFireTypes
import SwiftUI

struct SettingsView: View {
    let coordinator: AppCoordinator
    @State private var selectedTab: SettingsTab = .feedback

    var body: some View {
        VStack(spacing: 0) {
            // Primary navigation bar — always visible, high contrast
            HStack(spacing: Spacing.xs) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    SettingsTabButton(tab: tab, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(.bar)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .feedback:
                    FeedbackSettingsView(coordinator: coordinator)
                case .gestures:
                    GestureMappingView(coordinator: coordinator)
                case .advanced:
                    AdvancedSettingsView(coordinator: coordinator)
                case .logs:
                    LogViewerView(coordinator: coordinator)
                case .status:
                    StatusSettingsView(coordinator: coordinator)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Settings Tab

private enum SettingsTab: String, CaseIterable {
    case feedback, gestures, advanced, logs, status

    var label: String {
        switch self {
        case .feedback: "Feedback"
        case .gestures: "Gestures"
        case .advanced: "Advanced"
        case .logs: "Logs"
        case .status: "Status"
        }
    }

    var icon: String {
        switch self {
        case .feedback: "speaker.wave.2"
        case .gestures: "hand.tap"
        case .advanced: "slider.horizontal.3"
        case .logs: "clock"
        case .status: "stethoscope"
        }
    }
}

private struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(tab.label, systemImage: tab.icon)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    isSelected
                        ? Color.accentColor.opacity(0.12)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gesture Mapping

struct GestureMappingView: View {
    let coordinator: AppCoordinator
    var body: some View {
        Form {
            Section {
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
            } header: {
                Text("TipTap Gestures")
                    .font(.subheadline.weight(.medium))
            } footer: {
                Text("Format: Modifier+Key, e.g. cmd+left, ctrl+shift+t")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcut Field

struct ShortcutField: View {
    let shortcut: KeyShortcut?
    let onChange: (KeyShortcut?) -> Void
    @State private var text: String = ""
    @State private var parseError = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
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
                    .offset(y: Spacing.lg)
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
