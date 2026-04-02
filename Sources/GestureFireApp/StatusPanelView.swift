import GestureFireTypes
import SwiftUI

/// Content view for the floating status panel.
/// Shows the recognized gesture and fired shortcut.
struct StatusPanelView: View {
    let event: PipelineEvent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.systemImage)
                .font(.title2)
                .foregroundStyle(colorForEvent)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(.body, weight: .semibold))
                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var titleText: String {
        switch event {
        case .shortcutFired(let gesture, let shortcut, _):
            return "\(gesture.displayName) → \(shortcut)"
        case .recognized(let gesture, _):
            return "\(gesture.displayName) recognized"
        default:
            return event.displayDescription
        }
    }

    private var colorForEvent: Color {
        switch event.semanticColor {
        case .green: .green
        case .blue: .blue
        case .orange: .orange
        case .yellow: .yellow
        case .red: .red
        case .secondary: .secondary
        }
    }

    private var subtitleText: String? {
        switch event {
        case .shortcutFired:
            return "Shortcut fired"
        case .recognized:
            return "No shortcut mapped"
        default:
            return nil
        }
    }
}
