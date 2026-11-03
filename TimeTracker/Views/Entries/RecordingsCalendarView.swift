import SwiftUI

/// The Recordings tab's month calendar: days tinted by the projects recorded on them, and the
/// selected day's recordings underneath. Double-clicking a day adds a recording on it.
struct RecordingsCalendarView: View {
    @ObservedObject var viewModel: EntriesViewModel
    @Binding var calendarMonth: Date
    @Binding var selectedDate: Date
    let onEdit: (TimeEntry) -> Void
    let onAddEntry: (Date) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
                calendarHeader
                calendarGrid
                selectedDayEntries
            }
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.bottom, AppTheme.spacingLG)
        }
        .scrollIndicators(.hidden)
    }

    private var calendarHeader: some View {
        HStack(spacing: AppTheme.spacingMD) {
            Button(action: { moveCalendarMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glassCircle())

            VStack(alignment: .leading, spacing: 2) {
                Text(calendarMonthTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Text("\(monthEntryCount) recordings this month")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    calendarMonth = Date()
                    selectedDate = Date()
                }
            }) {
                Text("Today")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, AppTheme.spacingMD)
                    .frame(height: 36)
            }
            .buttonStyle(.glassCapsule())

            Button(action: { moveCalendarMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glassCircle())
        }
        .glassGroup(spacing: AppTheme.spacingSM)
        .padding(AppTheme.spacingMD)
        .cardSurface(cornerRadius: AppTheme.cornerRadiusXL)
    }

    private var monthEntryCount: Int {
        let calendar = Calendar.current
        return viewModel.entries.filter {
            calendar.isDate($0.startDate, equalTo: calendarMonth, toGranularity: .month)
        }.count
    }

    private var calendarGrid: some View {
        VStack(spacing: AppTheme.spacingSM) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(calendarDays, id: \.self) { date in
                    calendarDayCell(for: date)
                }
            }
        }
        .padding(AppTheme.spacingMD)
        .cardSurface(cornerRadius: AppTheme.cornerRadiusXL)
    }

    private func calendarDayCell(for date: Date) -> some View {
        let calendar = Calendar.current
        let entries = viewModel.entries(on: date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isCurrentMonth = calendar.isDate(date, equalTo: calendarMonth, toGranularity: .month)
        let projectColors = projectColorHexes(for: entries)
        let shape = RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)

        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedDate = date
            }
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(isToday ? AppTheme.onAccent : dayTextColor(hasEntries: !entries.isEmpty, isSelected: isSelected, isCurrentMonth: isCurrentMonth))
                    .frame(width: 24, height: 24)
                    .background(isToday ? AppTheme.accent : Color.clear, in: Circle())

                Spacer(minLength: 0)

                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(entries.prefix(2).enumerated()), id: \.offset) { _, entry in
                            Text(entry.name)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if entries.count > 2 {
                            Text("+\(entries.count - 2) more")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Text(DisplayFormatter.compactDuration(entries.reduce(0) { $0 + $1.duration }))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(AppTheme.textPrimary.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(AppTheme.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 104)
            .background {
                calendarDayBackground(projectColors: projectColors, hasEntries: !entries.isEmpty)
                    .clipShape(shape)
            }
            .overlay(
                shape.strokeBorder(isSelected ? AppTheme.accent.opacity(0.9) : AppTheme.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(shape)
            .hoverHighlight(cornerRadius: AppTheme.cornerRadiusMedium)
            .opacity(isCurrentMonth ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        // The first click selects the day as before; the second opens a new recording on it.
        .simultaneousGesture(TapGesture(count: 2).onEnded { onAddEntry(date) })
        .help("Double-click to add hours on this day")
    }

    @ViewBuilder
    private func calendarDayBackground(projectColors: [String], hasEntries: Bool) -> some View {
        if hasEntries, projectColors.count > 1 {
            LinearGradient(
                colors: projectColors.map { Color(hex: $0).opacity(0.34) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if hasEntries, let colorHex = projectColors.first {
            LinearGradient(
                colors: [Color(hex: colorHex).opacity(0.38), Color(hex: colorHex).opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.white.opacity(0.025)
        }
    }

    private func dayTextColor(hasEntries: Bool, isSelected: Bool, isCurrentMonth: Bool) -> Color {
        if hasEntries {
            return AppTheme.textPrimary
        }

        if isSelected {
            return AppTheme.accent
        }

        return isCurrentMonth ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.45)
    }

    private var selectedDayEntries: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            Text(selectedDayTitle)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            let dayEntries = viewModel.entries(on: selectedDate)
            if dayEntries.isEmpty {
                Text("No recordings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(AppTheme.spacingMD)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface(cornerRadius: AppTheme.cornerRadiusMedium, fill: AppTheme.surface.opacity(0.6))
            } else {
                ForEach(dayEntries, id: \.id) { entry in
                    EntryRowView(
                        entry: entry,
                        project: viewModel.project(for: entry.projectId),
                        onEdit: {
                            onEdit(entry)
                        },
                        onDelete: {
                            viewModel.deleteEntry(entry)
                        }
                    )
                }
            }
        }
    }

    private func projectColorHexes(for entries: [TimeEntry]) -> [String] {
        var seen = Set<String>()
        var colors: [String] = []

        for entry in entries {
            guard let colorHex = viewModel.project(for: entry.projectId)?.colorHex,
                  !seen.contains(colorHex) else {
                continue
            }

            seen.insert(colorHex)
            colors.append(colorHex)
        }

        return colors
    }

    private func moveCalendarMonth(by offset: Int) {
        calendarMonth = Calendar.current.date(byAdding: .month, value: offset, to: calendarMonth) ?? calendarMonth
    }

    private var calendarMonthTitle: String {
        DisplayFormatter.formatter(pattern: "MMMM yyyy").string(from: calendarMonth)
    }

    private var selectedDayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        }

        return DisplayFormatter.formatter(pattern: "EEEE, MMM d").string(from: selectedDate)
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstIndex = max(0, calendar.firstWeekday - 1)
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    private var calendarDays: [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: calendarMonth) else {
            return []
        }

        let firstDay = calendar.startOfDay(for: monthInterval.start)
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: firstDay) ?? firstDay

        return (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
    }
}
