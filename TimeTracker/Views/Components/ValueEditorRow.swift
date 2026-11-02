import SwiftUI

struct ValueEditorRow: View {
    let title: String
    let value: String
    var detail: String?
    var systemImage: String
    var accentColor: Color = AppTheme.accentBlue
    var isMuted: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingMD) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 42, height: 42)

                    Image(systemName: systemImage)
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppTheme.textSecondary)

                    Text(value)
                        .font(.body.weight(.semibold))
                        .foregroundColor(isMuted ? AppTheme.textSecondary : AppTheme.textPrimary)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(AppTheme.spacingMD)
            .background(AppTheme.surfaceMuted)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        }
        .buttonStyle(.plain)
    }
}
