import SwiftUI

struct CalendarWeekView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var selectedEntry: TimeEntry?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingSM) {
                weekdayHeader

                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(daysInWeek, id: \.self) { date in
                        WeekDayCell(
                            date: date,
                            entries: viewModel.entries(for: date),
                            markerColor: viewModel.dominantColor(for: viewModel.entries(for: date)),
                            isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
                        ) {
                            viewModel.selectedDate = date
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

    private var daysInWeek: [Date] {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: viewModel.selectedDate)) else {
            return []
        }

        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
}

struct WeekDayCell: View {
    let date: Date
    let entries: [TimeEntry]
    let markerColor: Color
    let isSelected: Bool
    let action: () -> Void

    private var totalDuration: TimeInterval {
        entries.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.spacingXS) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline)
                    .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)

                if !entries.isEmpty {
                    Capsule()
                        .fill(markerColor)
                        .frame(width: 8, height: 8)
                }

                if totalDuration > 0 {
                    Text(formattedDuration)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.spacingSM)
            .background(isSelected ? AppTheme.surface : Color.clear)
            .cornerRadius(AppTheme.cornerRadiusSmall)
        }
    }

    private var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
