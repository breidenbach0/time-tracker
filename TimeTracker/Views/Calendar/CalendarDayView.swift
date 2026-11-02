import SwiftUI

struct CalendarDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var selectedEntry: TimeEntry?

    var body: some View {
        ScrollView {
            if viewModel.entries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: AppTheme.spacingSM) {
                    ForEach(viewModel.entries, id: \.id) { entry in
                        EntryCard(
                            entry: entry,
                            project: viewModel.project(for: entry.projectId),
                            category: viewModel.category(for: entry.categoryId)
                        ) {
                            selectedEntry = entry
                        }
                    }
                }
                .padding(.horizontal, AppTheme.spacingMD)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingMD) {
            Spacer()
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textSecondary)
            Text("No recordings for this day")
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct EntryCard: View {
    let entry: TimeEntry
    let project: Project?
    let category: Category?
    let action: () -> Void
    @AppStorage(DisplayPreferenceKeys.timeFormat) private var timeFormatRawValue = TimeDisplayFormat.twentyFourHour.rawValue

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text(entry.name)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: AppTheme.spacingSM) {
                        if let project {
                            HStack(spacing: AppTheme.spacingXS) {
                                Circle()
                                    .fill(Color(hex: project.colorHex))
                                    .frame(width: 6, height: 6)
                                Text(project.name)
                            }
                        }

                        if let category {
                            HStack(spacing: AppTheme.spacingXS) {
                                Circle()
                                    .fill(Color(hex: category.colorHex))
                                    .frame(width: 6, height: 6)
                                Text(category.name)
                            }
                        }

                        Text(timeRange)
                    }
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: AppTheme.spacingXS) {
                    if entry.calendarEventIdentifier != nil {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.caption)
                            .foregroundColor(AppTheme.accentMint)
                    }

                    Text(entry.formattedDuration)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
            .padding(AppTheme.spacingMD)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
    }

    private var timeRange: String {
        let formatter = DisplayFormatter.timeFormatter(for: selectedTimeFormat)

        let start = formatter.string(from: entry.startDate)
        if let endDate = entry.endDate {
            let end = formatter.string(from: endDate)
            return "\(start) - \(end)"
        } else {
            return "\(start) - Now"
        }
    }

    private var selectedTimeFormat: TimeDisplayFormat {
        TimeDisplayFormat(rawValue: timeFormatRawValue) ?? .twentyFourHour
    }
}
