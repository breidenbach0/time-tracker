import SwiftUI

/// Picks the days to export: a ready-made range, or a start and an end day on the calendar.
/// Days in the last export carry a small dot.
struct ExportRangePickerSheet: View {
    let lastExportedRange: ClosedRange<Date>?
    let onCancel: () -> Void
    let onExport: (Date, Date) -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var displayedMonth: Date
    @State private var isChoosingEnd = false

    private let calendar = Calendar.current

    private enum Preset: CaseIterable, Identifiable {
        case thisWeek, lastWeek, thisMonth, lastMonth

        var id: Self { self }

        var title: String {
            switch self {
            case .thisWeek: return "This Week"
            case .lastWeek: return "Last Week"
            case .thisMonth: return "This Month"
            case .lastMonth: return "Last Month"
            }
        }
    }

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
                presets
                rangeFields
                calendarCard
                Spacer(minLength: 0)
                actions
            }
            .padding(AppTheme.spacingLG)
        }
        .frame(width: 460)
    }

    // MARK: - Header and ranges

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text("Choose the days for your PDF report.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glassCircle())
        }
    }

    private var presets: some View {
        HStack(spacing: AppTheme.spacingSM) {
            ForEach(Preset.allCases) { preset in
                SelectablePill(title: preset.title, isSelected: isShowing(preset)) {
                    apply(preset)
                }
            }
        }
    }

    private var rangeFields: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            HStack(spacing: AppTheme.spacingSM) {
                dateField(title: "From", date: min(startDate, endDate), isActive: !isChoosingEnd) {
                    isChoosingEnd = false
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)

                dateField(title: "To", date: max(startDate, endDate), isActive: isChoosingEnd) {
                    isChoosingEnd = true
                }
            }

            Text(isChoosingEnd ? "Now click the last day." : "Click a day to start the range.")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textTertiary)
                .animation(.easeOut(duration: 0.15), value: isChoosingEnd)
        }
    }

    private func dateField(title: String, date: Date, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                AppTheme.sectionLabel(title)
                Text(DisplayFormatter.formatter(pattern: "EEE, d MMM yyyy").string(from: date))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fieldSurface(cornerRadius: AppTheme.cornerRadiusMedium, isFocused: isActive)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Calendar

    private var calendarCard: some View {
        VStack(spacing: AppTheme.spacingMD) {
            monthHeader
            weekdayHeader

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { index, date in
                    dayCell(for: date, column: index % 7)
                }
            }

            if lastExportedRange != nil {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.textSecondary)
                        .frame(width: 4, height: 4)
                    Text("In your last export")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textTertiary)
                    Spacer()
                }
            }
        }
        .padding(AppTheme.spacingMD)
        .cardSurface(cornerRadius: AppTheme.cornerRadiusXL)
    }

    private var monthHeader: some View {
        HStack {
            Text(monthTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            HStack(spacing: AppTheme.spacingSM) {
                monthButton(systemImage: "chevron.left", offset: -1)
                monthButton(systemImage: "chevron.right", offset: 1)
            }
            .glassGroup(spacing: AppTheme.spacingSM)
        }
    }

    private func monthButton(systemImage: String, offset: Int) -> some View {
        Button(action: { moveMonth(by: offset) }) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.glassCircle())
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(reorderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// One day: blank outside the shown month, a band across the selected range, and a white
    /// circle on its first and last day.
    @ViewBuilder
    private func dayCell(for date: Date, column: Int) -> some View {
        let day = calendar.startOfDay(for: date)

        if calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month) {
            let lower = min(startDate, endDate)
            let upper = max(startDate, endDate)
            let isStart = calendar.isDate(day, inSameDayAs: lower)
            let isEnd = calendar.isDate(day, inSameDayAs: upper)
            let isInRange = day >= lower && day <= upper
            let isToday = calendar.isDateInToday(day)
            let wasExported = lastExportedRange.map { range in
                day >= calendar.startOfDay(for: range.lowerBound) && day <= calendar.startOfDay(for: range.upperBound)
            } ?? false

            Button(action: { select(day) }) {
                ZStack {
                    if isInRange && !(isStart && isEnd) {
                        RangeBand(
                            roundsLeading: isStart || column == 0 || isFirstOfMonth(day),
                            roundsTrailing: isEnd || column == 6 || isLastOfMonth(day),
                            startsAtCenter: isStart,
                            endsAtCenter: isEnd
                        )
                        .fill(AppTheme.surfaceAlt)
                    }

                    if isStart || isEnd {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 34, height: 34)
                    }

                    VStack(spacing: 2) {
                        Text("\(calendar.component(.day, from: day))")
                            .font(.system(size: 14, weight: isStart || isEnd || isToday ? .semibold : .regular))
                            .monospacedDigit()
                            .foregroundColor(isStart || isEnd ? AppTheme.onAccent : AppTheme.textPrimary)

                        Circle()
                            .fill(isStart || isEnd ? AppTheme.onAccent.opacity(0.5) : AppTheme.textSecondary)
                            .frame(width: 4, height: 4)
                            .opacity(wasExported ? 1 : 0)
                    }
                    .offset(y: 3)
                }
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isToday ? "Today" : "")
        } else {
            Color.clear.frame(height: 36)
        }
    }

    private var actions: some View {
        HStack(spacing: AppTheme.spacingSM) {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glassCapsule())
            .keyboardShortcut(.cancelAction)

            Button(action: { onExport(min(startDate, endDate), max(startDate, endDate)) }) {
                Label(exportTitle, systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glassCapsule(tint: AppTheme.accent.opacity(0.92)))
            .keyboardShortcut(.defaultAction)
        }
        .glassGroup(spacing: AppTheme.spacingSM)
    }

    private var exportTitle: String {
        let days = (calendar.dateComponents([.day], from: min(startDate, endDate), to: max(startDate, endDate)).day ?? 0) + 1
        return days == 1 ? "Export 1 Day" : "Export \(days) Days"
    }

    // MARK: - Choosing

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

    private func range(for preset: Preset) -> (Date, Date) {
        let today = calendar.startOfDay(for: Date())
        let week = calendar.dateInterval(of: .weekOfYear, for: today)
        let month = calendar.dateInterval(of: .month, for: today)

        switch preset {
        case .thisWeek:
            return (week?.start ?? today, today)
        case .lastWeek:
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: week?.start ?? today) ?? today
            return (start, calendar.date(byAdding: .day, value: 6, to: start) ?? start)
        case .thisMonth:
            return (month?.start ?? today, today)
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: month?.start ?? today) ?? today
            let end = calendar.date(byAdding: .day, value: -1, to: month?.start ?? today) ?? start
            return (start, end)
        }
    }

    private func apply(_ preset: Preset) {
        let (start, end) = range(for: preset)
        withAnimation(.easeOut(duration: 0.15)) {
            startDate = start
            endDate = end
            displayedMonth = end
            isChoosingEnd = false
        }
    }

    private func isShowing(_ preset: Preset) -> Bool {
        let (start, end) = range(for: preset)
        return calendar.isDate(min(startDate, endDate), inSameDayAs: start)
            && calendar.isDate(max(startDate, endDate), inSameDayAs: end)
    }

    private func moveMonth(by offset: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
    }

    private func isFirstOfMonth(_ day: Date) -> Bool {
        calendar.component(.day, from: day) == 1
    }

    private func isLastOfMonth(_ day: Date) -> Bool {
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
        return !calendar.isDate(next, equalTo: day, toGranularity: .month)
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

    private var reorderedWeekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstIndex = max(0, calendar.firstWeekday - 1)
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }
}

/// The selected range's band behind one day cell: from the cell's centre on the range's first
/// and last day, edge to edge in between, rounded where the band starts or stops in a row.
private struct RangeBand: Shape {
    let roundsLeading: Bool
    let roundsTrailing: Bool
    let startsAtCenter: Bool
    let endsAtCenter: Bool

    func path(in rect: CGRect) -> Path {
        let height: CGFloat = 34
        let minX = startsAtCenter ? rect.midX : rect.minX
        let maxX = endsAtCenter ? rect.midX : rect.maxX
        let band = CGRect(x: minX, y: rect.midY - height / 2, width: max(0, maxX - minX), height: height)
        let radius = height / 2
        let leading = roundsLeading && !startsAtCenter
        let trailing = roundsTrailing && !endsAtCenter

        // Drawn by hand: per-corner radii need macOS 14.
        var path = Path()
        path.move(to: CGPoint(x: band.minX + (leading ? radius : 0), y: band.minY))
        path.addLine(to: CGPoint(x: band.maxX - (trailing ? radius : 0), y: band.minY))
        if trailing {
            path.addArc(center: CGPoint(x: band.maxX - radius, y: band.midY), radius: radius,
                        startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: band.maxX, y: band.maxY))
        }
        path.addLine(to: CGPoint(x: band.minX + (leading ? radius : 0), y: band.maxY))
        if leading {
            path.addArc(center: CGPoint(x: band.minX + radius, y: band.midY), radius: radius,
                        startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: band.minX, y: band.minY))
        }
        path.closeSubpath()
        return path
    }
}
