import GestureFireConfig
import GestureFireEngine
import GestureFireTypes
import SwiftUI

struct SettingsView: View {
    let coordinator: AppCoordinator
    @State private var selectedTab: SettingsTab = .feedback
    @FocusState private var focusedTab: SettingsTab?

    var body: some View {
        VStack(spacing: 0) {
            // Primary navigation bar — focusable, arrow-key navigable
            HStack(spacing: Spacing.xs) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    SettingsTabItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        isFocused: focusedTab == tab
                    ) {
                        selectedTab = tab
                    }
                    .focused($focusedTab, equals: tab)
                }
            }
            .onMoveCommand { direction in
                moveTab(direction)
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
        // Hidden buttons for Cmd+1..5 shortcuts (keyboardShortcut requires Button)
        .background {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button("") { selectedTab = tab }
                    .keyboardShortcut(tab.shortcutKey, modifiers: .command)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
    }

    private func moveTab(_ direction: MoveCommandDirection) {
        let tabs = SettingsTab.allCases
        let current = focusedTab ?? selectedTab
        guard let index = tabs.firstIndex(of: current) else { return }
        let newIndex: Int
        switch direction {
        case .left: newIndex = max(0, index - 1)
        case .right: newIndex = min(tabs.count - 1, index + 1)
        default: return
        }
        let newTab = tabs[newIndex]
        focusedTab = newTab
        selectedTab = newTab
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

// MARK: - Tab Bar Item

/// A focusable tab bar item. Uses `.focusable()` instead of `Button` so that it
/// participates in the macOS Tab-key focus chain without requiring the system
/// "Keyboard Navigation" setting. Visual appearance matches the original design.
private struct SettingsTabItem: View {
    let tab: SettingsTab
    let isSelected: Bool
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
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
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .opacity(isFocused ? 1 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.return) { action(); return .handled }
            .onKeyPress(.space) { action(); return .handled }
            .onTapGesture { action() }
            .accessibilityLabel("\(tab.label) tab")
            .accessibilityAddTraits(.isButton)
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
                caption: "Rest one finger on the trackpad, then quickly tap with a second finger to the left, right, above, or below the resting finger. Keep the first finger still throughout.",
                gestures: [.tipTapLeft, .tipTapRight, .tipTapUp, .tipTapDown]
            ),
            GestureFamily(
                id: "multifingertap",
                title: "Multi-Finger Tap",
                caption: "Place 3, 4, or 5 fingers flat on the trackpad at the same time, then lift them all quickly. Keep your fingers close together and avoid sliding.",
                gestures: [.multiFingerTap3, .multiFingerTap4, .multiFingerTap5]
            ),
            GestureFamily(
                id: "swipe3",
                title: "3-Finger Swipe",
                caption: "Place 3 fingers close together on the trackpad and slide them in one direction, then lift. Keep the fingers moving as a group. Note: if macOS uses 3-finger swipes for Mission Control or Spaces, disable that in System Settings \u{2192} Trackpad \u{2192} More Gestures.",
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
                caption: "Place 4 fingers close together on the trackpad and slide them in one direction, then lift. Keep the fingers moving as a group.",
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
                caption: "Tap once with a single finger inside one of the four corners of the trackpad. The corner region covers roughly the outer 15% of each edge.",
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
