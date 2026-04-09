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

    /// Cmd+1..5 tab shortcut. Index matches the order in `allCases`.
    var shortcutKey: KeyEquivalent {
        switch self {
        case .feedback: "1"
        case .gestures: "2"
        case .advanced: "3"
        case .logs: "4"
        case .status: "5"
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
        .keyboardShortcut(tab.shortcutKey, modifiers: .command)
        .accessibilityLabel("\(tab.label) tab")
        .accessibilityHint(Text(verbatim: "Press Command \(String(tab.shortcutKey.character)) to switch to the \(tab.label) tab."))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Gesture Mapping

/// A group of related gestures rendered as one section in the mapping view.
private struct GestureFamily: Identifiable {
    let id: String
    let title: String
    let caption: String?
    let gestures: [GestureType]
}

struct GestureMappingView: View {
    let coordinator: AppCoordinator

    private var families: [GestureFamily] {
        [
            GestureFamily(
                id: "tiptap",
                title: "TipTap",
                caption: "Hold one finger, tap another in a direction.",
                gestures: [.tipTapLeft, .tipTapRight, .tipTapUp, .tipTapDown]
            ),
            GestureFamily(
                id: "multifingertap",
                title: "Multi-Finger Tap",
                caption: "Tap several fingers together and lift.",
                gestures: [.multiFingerTap3, .multiFingerTap4, .multiFingerTap5]
            ),
            GestureFamily(
                id: "swipe3",
                title: "3-Finger Swipe",
                caption: "Place three fingers and slide in a direction.",
                gestures: [
                    .multiFingerSwipe3Left,
                    .multiFingerSwipe3Right,
                    .multiFingerSwipe3Up,
                    .multiFingerSwipe3Down,
                ]
            ),
            GestureFamily(
                id: "swipe4",
                title: "4-Finger Swipe",
                caption: "Place four fingers and slide in a direction.",
                gestures: [
                    .multiFingerSwipe4Left,
                    .multiFingerSwipe4Right,
                    .multiFingerSwipe4Up,
                    .multiFingerSwipe4Down,
                ]
            ),
            GestureFamily(
                id: "corner",
                title: "Corner Tap",
                caption: "Single-finger tap inside a corner region.",
                gestures: [
                    .cornerTapTopLeft,
                    .cornerTapTopRight,
                    .cornerTapBottomLeft,
                    .cornerTapBottomRight,
                ]
            ),
        ]
    }

    var body: some View {
        Form {
            ForEach(families) { family in
                Section {
                    ForEach(family.gestures, id: \.self) { gesture in
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
                            .accessibilityLabel("\(gesture.displayName) shortcut")
                        }
                    }
                } header: {
                    Text(family.title)
                        .font(.subheadline.weight(.medium))
                        .accessibilityAddTraits(.isHeader)
                } footer: {
                    if let caption = family.caption {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text("Shortcut format: Modifier+Key, e.g. cmd+left, ctrl+shift+t")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
