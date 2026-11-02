import SwiftUI

struct EntryRowView: View {
    let entry: TimeEntry
    let project: Project?
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.spacingSM) {
            Button(action: onEdit) {
                HStack(spacing: AppTheme.spacingMD) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(projectTint)
                        .frame(width: 3, height: 28)
                        .shadow(color: projectTint.opacity(0.6), radius: 4)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        projectLabel
                    }
                    .layoutPriority(1)

                    Spacer(minLength: AppTheme.spacingXS)

                    Text(entry.formattedDuration)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .monospacedDigit()
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 24, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 24, alignment: .trailing)
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.vertical, 12)
        .cardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        .hoverHighlight(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var projectTint: Color {
        Color(hex: project?.colorHex ?? "#6F6F6F")
    }

    @ViewBuilder
    private var projectLabel: some View {
        HStack(spacing: AppTheme.spacingXS) {
            Text(project?.name ?? "No Project")
                .lineLimit(1)
                .truncationMode(.tail)

            if !entry.notes.isEmpty {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 10, weight: .semibold))
                    .help(entry.notes)
            }
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundColor(AppTheme.textSecondary)
    }
}
