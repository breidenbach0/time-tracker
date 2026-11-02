import SwiftUI

struct CalendarListView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var selectedEntry: TimeEntry?

    var body: some View {
        ScrollView {
            if viewModel.entries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: AppTheme.spacingSM) {
                    ForEach(groupedEntries.keys.sorted(by: >), id: \.self) { date in
                        Section {
                            ForEach(groupedEntries[date] ?? [], id: \.id) { entry in
                                EntryCard(
                                    entry: entry,
                                    project: viewModel.project(for: entry.projectId),
                                    category: viewModel.category(for: entry.categoryId)
                                ) {
                                    selectedEntry = entry
                                }
                            }
                        } header: {
                            HStack {
                                Text(formatSectionDate(date))
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Text(totalDurationText(for: date))
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .padding(.top, AppTheme.spacingMD)
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
            Text("No recordings yet")
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var groupedEntries: [Date: [TimeEntry]] {
        let calendar = Calendar.current
        var groups: [Date: [TimeEntry]] = [:]

        for entry in viewModel.entries {
            let startOfDay = calendar.startOfDay(for: entry.startDate)
            groups[startOfDay, default: []].append(entry)
        }

        return groups
    }

    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }

    private func totalDurationText(for date: Date) -> String {
        guard let entries = groupedEntries[date] else { return "" }
        let total = entries.reduce(0) { $0 + $1.duration }
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60

        return String(format: "%dh %dm", hours, minutes)
    }
}
