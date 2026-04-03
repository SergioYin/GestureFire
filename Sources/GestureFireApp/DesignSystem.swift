import SwiftUI

// MARK: - Spacing

/// Consistent spacing constants on a 4pt grid.
/// Use these instead of hardcoded padding values.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - SettingsCard

/// Wraps content in a rounded rectangle with system grouped background.
/// Use for visual grouping in settings tabs.
struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.lg)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - StatusBadge

/// Icon + text in a tinted capsule. Used for engine state and diagnostic results.
struct StatusBadge: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, Spacing.xs)
        .foregroundStyle(color)
        .background(color.opacity(0.12), in: Capsule())
    }
}
