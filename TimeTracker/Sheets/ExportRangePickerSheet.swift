import SwiftUI

/// Picks the days to export, marking the ones in the last export.
struct ExportRangePickerSheet: View {
    let lastExportedRange: ClosedRange<Date>?
    let onCancel: () -> Void
    let onExport: (Date, Date) -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var displayedMonth: Date
    @State private var isChoosingEnd = false

    private let calendar = Calendar.current
    private let orange = AppTheme.warning

    init(
        lastExportedRange: ClosedRange<Date>?,
        onCancel: @escaping () -> Void,
        onExport: @escaping (Date, Date) -> Void
    ) {
        self.lastExportedRange = lastExportedRange
        self.onCancel = onCancel
        self.onExport = onExport

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let defaultStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        _startDate = State(initialValue: defaultStart)
        _endDate = State(initialValue: today)
        _displayedMonth = State(initialValue: today)
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
                header
                rangeSummary
                calendarCard
                legend
                Spacer(minLength: 0)
                actions
            }
            .padding(AppTheme.spacingLG)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export Range")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Text("Pick the exact days you want in the PDF.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glassCircle())
        }
    }

    private var rangeSummary: some View {
        HStack {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            Text(rangeText)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .monospacedDigit()

            Spacer()

            Text(isChoosingEnd ? "Pick end" : "Pick start")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundColor(isChoosingEnd ? orange : AppTheme.textSecondary)
                .padding(.horizontal, AppTheme.spacingSM)
                .padding(.vertical, AppTheme.spacingXS)
                .background((isChoosingEnd ? orange.opacity(0.18) : AppTheme.surfaceAlt), in: Capsule())
        }
        .padding(AppTheme.spacingMD)
        .fieldSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var calendarCard: some View {
        VStack(spacing: AppTheme.spacingMD) {
            monthHeader
            weekdayHeader

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppTheme.spacingXS), count: 7), spacing: AppTheme.spacingXS) {
                ForEach(calendarDays, id: \.self) { date in
                    dayButton(for: date)
                }
            }
        }
        .padding(AppTheme.spacingMD)
        .cardSurface(cornerRadius: AppTheme.cornerRadiusXL)
    }

    private var monthHeader: some View {
        HStack {
            Button(action: { moveMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glassCircle())

            Spacer()

            Text(monthTitle)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Button(action: { moveMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glassCircle())
        }
    }

    private var weekdayHeader: some View {
        let symbols = reorderedWeekdaySymbols

        return HStack(spacing: AppTheme.spacingXS) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: AppTheme.spacingSM) {
            Circle()
                .fill(orange)
                .frame(width: 8, height: 8)

            Text("Orange days were included in your last export.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)

            Spacer()
        }
    }

    private var actions: some View {
        HStack(spacing: AppTheme.spacingSM) {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glassCapsule())
            .keyboardShortcut(.cancelAction)

            Button(action: { onExport(startDate, endDate) }) {
                Label("Export PDF", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glassCapsule(tint: AppTheme.accent.opacity(0.92)))
            .keyboardShortcut(.defaultAction)
        }
        .glassGroup(spacing: AppTheme.spacingSM)
    }

    private func dayButton(for date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let isCurrentMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let isEndpoint = calendar.isDate(day, inSameDayAs: startDate) || calendar.isDate(day, inSameDayAs: endDate)
        let isSelectedRange = day >= min(startDate, endDate) && day <= max(startDate, endDate)
        let wasExported = lastExportedRange.map { range in
            day >= calendar.startOfDay(for: range.lowerBound) && day <= calendar.startOfDay(for: range.upperBound)
        } ?? false

        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        return Button(action: { select(day) }) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 14, weight: isEndpoint ? .bold : .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(dayTextColor(isCurrentMonth: isCurrentMonth, isEndpoint: isEndpoint))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(dayBackground(isEndpoint: isEndpoint, isSelectedRange: isSelectedRange, wasExported: wasExported), in: shape)
                .overlay(
                    shape.strokeBorder(wasExported && !isEndpoint ? orange.opacity(0.55) : Color.clear, lineWidth: 1)
                )
                .contentShape(shape)
                .hoverHighlight(cornerRadius: 10)
        }
        .buttonStyle(.plain)
    }

    private func dayTextColor(isCurrentMonth: Bool, isEndpoint: Bool) -> Color {
        if isEndpoint {
            return AppTheme.onAccent
        }

        return isCurrentMonth ? AppTheme.textPrimary : AppTheme.textTertiary
    }

    private func dayBackground(isEndpoint: Bool, isSelectedRange: Bool, wasExported: Bool) -> Color {
        if isEndpoint {
            return AppTheme.accent
        }

        if isSelectedRange {
            return AppTheme.surfaceAlt
        }

        if wasExported {
            return orange.opacity(0.16)
        }

        return Color.clear
    }

    private func select(_ date: Date) {
        if isChoosingEnd {
            if date < startDate {
                endDate = startDate
                startDate = date
            } else {
                endDate = date
            }
            isChoosingEnd = false
        } else {
            startDate = date
            endDate = date
            isChoosingEnd = true
        }
    }

    private func moveMonth(by offset: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
    }

    private var calendarDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
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

    private var monthTitle: String {
        DisplayFormatter.formatter(pattern: "MMMM yyyy").string(from: displayedMonth)
    }

    private var rangeText: String {
        let formatter = DisplayFormatter.formatter(pattern: "dd.MM.yyyy")
        return "\(formatter.string(from: min(startDate, endDate))) - \(formatter.string(from: max(startDate, endDate)))"
    }

    private var reorderedWeekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstIndex = max(0, calendar.firstWeekday - 1)
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }
}
