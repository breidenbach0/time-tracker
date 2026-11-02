import SwiftUI

struct CalendarMonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var selectedEntry: TimeEntry?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingSM) {
                weekdayHeader

                ForEach(weeksInMonth, id: \.self) { week in
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(week, id: \.self) { date in
                            MonthDayCell(
                                date: date,
                                entries: viewModel.entries(for: date),
                                markerColors: viewModel.entries(for: date).prefix(3).map { viewModel.color(for: $0) },
                                isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate),
                                isCurrentMonth: Calendar.current.isDate(date, equalTo: viewModel.selectedDate, toGranularity: .month)
                            ) {
                                viewModel.selectedDate = date
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingMD)
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekdaySymbols: [String] {
        ["S", "M", "T", "W", "T", "F", "S"]
    }

    private var weeksInMonth: [[Date]] {
        let calendar = Calendar.current
        var weeks: [[Date]] = []

        guard let monthInterval = calendar.dateInterval(of: .month, for: viewModel.selectedDate) else {
            return []
        }

        let firstOfMonth = monthInterval.start

        var currentWeek: [Date] = []
        let adjustedFirstSunday = calendar.date(byAdding: .day, value: -(calendar.component(.weekday, from: firstOfMonth) - 1), to: firstOfMonth)!

        var currentDate = adjustedFirstSunday
        for _ in 0..<42 {
            currentWeek.append(currentDate)

            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return weeks
    }
}

struct MonthDayCell: View {
    let date: Date
    let entries: [TimeEntry]
    let markerColors: [Color]
    let isSelected: Bool
    let isCurrentMonth: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.spacingXS) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline)
                    .foregroundColor(textColor)

                HStack(spacing: 2) {
                    ForEach(Array(markerColors.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.spacingSM)
            .background(isSelected ? AppTheme.surface : Color.clear)
            .cornerRadius(AppTheme.cornerRadiusSmall)
        }
    }

    private var textColor: Color {
        if isSelected {
            return AppTheme.textPrimary
        } else if isCurrentMonth {
            return AppTheme.textPrimary
        } else {
            return AppTheme.textSecondary.opacity(0.5)
        }
    }
}
