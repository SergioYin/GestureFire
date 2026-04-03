import GestureFireTypes
import SwiftUI

/// Content view for the floating status panel.
/// Shows the recognized gesture and fired shortcut.
struct StatusPanelView: View {
    let event: PipelineEvent

    var body: some View {
        HStack(spacing: 0) {
            // Accent left border
            RoundedRectangle(cornerRadius: 1.5)
                .fill(colorForEvent)
                .frame(width: 3)
                .padding(.vertical, Spacing.sm)

            HStack(spacing: Spacing.md) {
                Image(systemName: event.systemImage)
                    .font(.title)
                    .foregroundStyle(colorForEvent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.headline)
                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 10))
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
            return "Shortcut sent"
        case .recognized:
            return "Recognized (no shortcut)"
        default:
            return nil
        }
    }
}
