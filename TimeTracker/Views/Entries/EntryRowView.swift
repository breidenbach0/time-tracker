import SwiftUI

struct EntryRowView: View {
    let entry: TimeEntry
    let project: Project?
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.spacingSM) {
            Button(action: onEdit) {
                HStack(spacing: AppTheme.spacingSM) {
                    Text(entry.name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(2)

                    HStack(spacing: AppTheme.spacingSM) {
                        projectLabel
                    }
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                    Spacer(minLength: AppTheme.spacingXS)

                    Text(entry.formattedDuration)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                        .frame(width: 100, alignment: .trailing)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button("Edit", action: onEdit)
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 20, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 20, alignment: .trailing)
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.vertical, AppTheme.spacingMD)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    @ViewBuilder
    private var projectLabel: some View {
        if let project {
            HStack(spacing: AppTheme.spacingXS) {
                Circle()
                    .fill(Color(hex: project.colorHex))
                    .frame(width: 7, height: 7)
                Text(project.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
        } else {
            Text("No Project")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

}
