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
            HStack(spacing: AppTheme.spacingSM) {
                if let colorHex {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 10, height: 10)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.vertical, AppTheme.spacingSM)
            .background(isSelected ? AppTheme.surface : AppTheme.surfaceMuted.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusFull)
                    .stroke(isSelected ? AppTheme.accentBlue : AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusFull))
        }
        .buttonStyle(.plain)
    }
}
