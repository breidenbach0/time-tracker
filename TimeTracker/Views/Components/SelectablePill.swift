import SwiftUI

struct SelectablePill: View {
    let title: String
    let colorHex: String?
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    init(
        title: String,
        colorHex: String? = nil,
        systemImage: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.colorHex = colorHex
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let colorHex {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 8, height: 8)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? AppTheme.surfaceAlt : AppTheme.surface.opacity(0.6), in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? AppTheme.highlight : AppTheme.border, lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
            .hoverHighlight(cornerRadius: 20)
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
