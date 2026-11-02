import AppKit
import SwiftUI

private enum RecordingsDisplayMode: String {
    case list
    case calendar

    var systemImage: String {
        switch self {
        case .list:
            return "list.bullet.rectangle"
        case .calendar:
            return "calendar"
        }
    }
}

struct EntriesListView: View {
    @StateObject private var viewModel = EntriesViewModel()
    @State private var showingAddSheet = false
    @State private var showingExportRangePicker = false
    @State private var selectedEntry: TimeEntry?
    @State private var exportErrorMessage: String?
    @State private var calendarMonth = Date()
    @State private var selectedCalendarDate = Date()
    @AppStorage("recordings_display_mode") private var displayModeRawValue = RecordingsDisplayMode.list.rawValue
    @AppStorage("last_exported_range_start") private var lastExportedRangeStart: Double = 0
    @AppStorage("last_exported_range_end") private var lastExportedRangeEnd: Double = 0
    private let contentWidth: CGFloat = 980

    var body: some View {
        ZStack {
            AppTheme.primary.ignoresSafeArea()

            VStack(spacing: 0) {
                centeredContent {
                    topSection
                }

                if viewModel.entries.isEmpty {
                    centeredContent {
                        emptyState
                    }
                } else {
                    centeredContent {
                        if selectedDisplayMode == .list {
                            entriesList
                        } else {
                            recordingsCalendar
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEntrySheet {
                viewModel.loadWorkspace()
                viewModel.loadEntries()
            }
        }
        .sheet(item: $selectedEntry) { entry in
            AddEntrySheet(editingEntry: entry) {
                viewModel.loadWorkspace()
                viewModel.loadEntries()
            }
        }
        .sheet(isPresented: $showingExportRangePicker) {
            ExportRangePickerSheet(
                lastExportedRange: lastExportedRange,
                onCancel: {
                    showingExportRangePicker = false
                },
                onExport: { startDate, endDate in
                    exportEntries(from: startDate, to: endDate)
                    showingExportRangePicker = false
                }
            )
            .frame(minWidth: 430, minHeight: 560)
        }
        .onAppear {
            viewModel.loadWorkspace()
            viewModel.loadEntries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workspaceDidChange)) { _ in
            viewModel.loadWorkspace()
            viewModel.loadEntries()
        }
        .alert("Export", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private var topSection: some View {
        HStack(alignment: .bottom, spacing: AppTheme.spacingLG) {
            VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                Text("Recordings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.spacingSM) {
                        SelectablePill(
                            title: "All Projects",
                            systemImage: "square.grid.2x2",
                            isSelected: viewModel.selectedProjectFilterId == nil
                        ) {
                            viewModel.selectProjectFilter(nil)
                        }

                        ForEach(viewModel.projects) { project in
                            SelectablePill(
                                title: project.name,
                                colorHex: project.colorHex,
                                isSelected: project.id == viewModel.selectedProjectFilterId
                            ) {
                                viewModel.selectProjectFilter(project.id)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                displayModeToggle

                Button(action: { showingExportRangePicker = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 2)
                .disabled(viewModel.entries.isEmpty)

                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.primary)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 2)
            }
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.top, AppTheme.spacingMD)
        .padding(.bottom, AppTheme.spacingMD)
    }

    private var displayModeToggle: some View {
        HStack(spacing: 4) {
            displayModeButton(.list)
            displayModeButton(.calendar)
        }
        .padding(4)
        .background(AppTheme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.bottom, 2)
    }

    private func displayModeButton(_ mode: RecordingsDisplayMode) -> some View {
        Button {
            displayModeRawValue = mode.rawValue
        } label: {
            Image(systemName: mode.systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(selectedDisplayMode == mode ? AppTheme.primary : AppTheme.textSecondary)
                .frame(width: 36, height: 36)
                .background(selectedDisplayMode == mode ? AppTheme.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .help(mode == .list ? "List view" : "Calendar view")
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
            Button(action: { showingAddSheet = true }) {
                Label("Create Recording", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(AppTheme.primary)
                    .padding(.horizontal, AppTheme.spacingMD)
                    .padding(.vertical, AppTheme.spacingSM)
                    .background(AppTheme.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private var entriesList: some View {
        List {
            ForEach(viewModel.daySections) { section in
                Section {
                    ForEach(section.entries, id: \.id) { entry in
                        EntryRowView(
                            entry: entry,
                            project: viewModel.project(for: entry.projectId),
                            onEdit: {
                                selectedEntry = entry
                            },
                            onDelete: {
                                viewModel.deleteEntry(entry)
                            }
                        )
                        .listRowInsets(EdgeInsets(
                            top: AppTheme.spacingSM,
                            leading: 0,
                            bottom: AppTheme.spacingSM,
                            trailing: 0
                        ))
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    HStack {
                        Text(formatSectionDate(section.day))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.top, AppTheme.spacingSM)
                    .padding(.bottom, AppTheme.spacingXS)
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity)
    }

    private var recordingsCalendar: some View {
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(calendarMonthTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Text("\(viewModel.entries.count) recordings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Button(action: {
                calendarMonth = Date()
                selectedCalendarDate = Date()
            }) {
                Text("Today")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, AppTheme.spacingMD)
                    .frame(height: 40)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button(action: { moveCalendarMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(AppTheme.spacingMD)
        .background(AppTheme.surfaceMuted)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    private var calendarGrid: some View {
        VStack(spacing: AppTheme.spacingSM) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppTheme.spacingSM), count: 7), spacing: AppTheme.spacingSM) {
                ForEach(calendarDays, id: \.self) { date in
                    calendarDayCell(for: date)
                }
            }
        }
        .padding(AppTheme.spacingMD)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    private func calendarDayCell(for date: Date) -> some View {
        let calendar = Calendar.current
        let entries = viewModel.entries(on: date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedCalendarDate)
        let isCurrentMonth = calendar.isDate(date, equalTo: calendarMonth, toGranularity: .month)
        let projectColors = projectColorHexes(for: entries)

        return Button {
            selectedCalendarDate = date
        } label: {
            VStack(spacing: AppTheme.spacingXS) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(dayTextColor(hasEntries: !entries.isEmpty, isSelected: isSelected, isCurrentMonth: isCurrentMonth))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(entries.prefix(2).enumerated()), id: \.offset) { _, entry in
                            Text(entry.name)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if entries.count > 2 {
                            Text("+\(entries.count - 2) more")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary.opacity(0.78))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Text(compactDuration(entries.reduce(0) { $0 + $1.duration }))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.textPrimary.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(AppTheme.spacingSM)
            .frame(height: 112)
            .background {
                calendarDayBackground(projectColors: projectColors, hasEntries: !entries.isEmpty)
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(isSelected ? AppTheme.accent : AppTheme.border, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            .opacity(isCurrentMonth ? 1 : 0.52)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func calendarDayBackground(projectColors: [String], hasEntries: Bool) -> some View {
        if hasEntries, projectColors.count > 1 {
            LinearGradient(
                colors: projectColors.map { Color(hex: $0).opacity(0.82) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if hasEntries, let colorHex = projectColors.first {
            Color(hex: colorHex).opacity(0.82)
        } else {
            AppTheme.surfaceMuted.opacity(0.55)
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
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            let dayEntries = viewModel.entries(on: selectedCalendarDate)
            if dayEntries.isEmpty {
                Text("No recordings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(AppTheme.spacingMD)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            } else {
                ForEach(dayEntries, id: \.id) { entry in
                    EntryRowView(
                        entry: entry,
                        project: viewModel.project(for: entry.projectId),
                        onEdit: {
                            selectedEntry = entry
                        },
                        onDelete: {
                            viewModel.deleteEntry(entry)
                        }
                    )
                }
            }
        }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return DisplayFormatter.formatter(pattern: "EEEE, MMM d").string(from: date)
        }
    }

    private func centeredContent<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Spacer(minLength: AppTheme.spacingLG)
            content()
                .frame(maxWidth: contentWidth)
            Spacer(minLength: AppTheme.spacingLG)
        }
        .padding(.horizontal, AppTheme.spacingMD)
    }

    private var selectedDisplayMode: RecordingsDisplayMode {
        RecordingsDisplayMode(rawValue: displayModeRawValue) ?? .list
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
        if calendar.isDateInToday(selectedCalendarDate) {
            return "Today"
        }

        return DisplayFormatter.formatter(pattern: "EEEE, MMM d").string(from: selectedCalendarDate)
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

    private func compactDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(remainingMinutes)m"
    }

    private var lastExportedRange: ClosedRange<Date>? {
        guard lastExportedRangeStart > 0, lastExportedRangeEnd > 0 else {
            return nil
        }

        let start = Date(timeIntervalSince1970: min(lastExportedRangeStart, lastExportedRangeEnd))
        let end = Date(timeIntervalSince1970: max(lastExportedRangeStart, lastExportedRangeEnd))
        return start...end
    }

    private func exportEntries(for period: ExportPeriod) {
        let exportEntries = viewModel.exportEntries(for: period)

        guard !exportEntries.isEmpty else {
            exportErrorMessage = "There are no recordings in \(period.title.lowercased()) to export."
            return
        }

        do {
            let fileURL = try writeExportFile(for: exportEntries, period: period)
            presentShareSheet(for: fileURL)
        } catch {
            exportErrorMessage = "TimeTracker could not export those recordings: \(error.localizedDescription)"
        }
    }

    private func exportEntries(from startDate: Date, to endDate: Date) {
        let exportEntries = viewModel.exportEntries(from: startDate, to: endDate)
        let periodTitle = rangeTitle(from: startDate, to: endDate)

        guard !exportEntries.isEmpty else {
            exportErrorMessage = "There are no recordings in \(periodTitle.lowercased()) to export."
            return
        }

        do {
            let fileURL = try writeExportFile(for: exportEntries, periodTitle: periodTitle, startDate: startDate, endDate: endDate)
            let calendar = Calendar.current
            lastExportedRangeStart = calendar.startOfDay(for: min(startDate, endDate)).timeIntervalSince1970
            lastExportedRangeEnd = calendar.startOfDay(for: max(startDate, endDate)).timeIntervalSince1970
            presentShareSheet(for: fileURL)
        } catch {
            exportErrorMessage = "TimeTracker could not export those recordings: \(error.localizedDescription)"
        }
    }

    private func writeExportFile(for exportEntries: [TimeEntry], period: ExportPeriod) throws -> URL {
        try writeExportFile(
            for: exportEntries,
            periodTitle: period.title,
            startDate: nil,
            endDate: nil,
            fileSlug: period.rawValue
        )
    }

    private func writeExportFile(
        for exportEntries: [TimeEntry],
        periodTitle: String,
        startDate: Date?,
        endDate: Date?,
        fileSlug: String? = nil
    ) throws -> URL {
        DatabaseManager.ensureStorageDirectories()

        let report = exportReportText(for: exportEntries, periodTitle: periodTitle)
        let slug = fileSlug ?? rangeSlug(from: startDate, to: endDate)
        let fileName = "timetracker-\(slug)-\(dateStamp).pdf"
        let fileURL = DatabaseManager.exportsDirectoryURL.appendingPathComponent(fileName)
        let pdfData = try buildPDF(from: report)
        try pdfData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func exportReportText(for exportEntries: [TimeEntry], period: ExportPeriod) -> String {
        exportReportText(for: exportEntries, periodTitle: period.title)
    }

    private func exportReportText(for exportEntries: [TimeEntry], periodTitle: String) -> String {
        let dateFormatter = DisplayFormatter.formatter(pattern: "dd.MM.yy")
        let timeFormatter = DisplayFormatter.formatter(pattern: "HH:mm")

        let rows = exportEntries.sorted(by: { $0.startDate > $1.startDate }).map { entry in
            let start = timeFormatter.string(from: entry.startDate)
            let end = entry.endDate.map { timeFormatter.string(from: $0) } ?? "-"
            let entryDate = dateFormatter.string(from: entry.startDate)
            let noteText = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let hours = Int(entry.duration) / 3600
            let minutes = (Int(entry.duration) % 3600) / 60
            let seconds = Int(entry.duration) % 60
            let totalWorked = String(format: "%02d:%02d:%02d", hours, minutes, seconds)

            return """
            \(entry.name)
            Note: \(noteText.isEmpty ? "-" : noteText)
            Date: \(entryDate)
            Start: \(start)
            End: \(end)
            Total Worked: \(totalWorked)
            """
        }

        let activeProject = viewModel.selectedProjectFilterId.flatMap { viewModel.project(for: $0)?.name } ?? "All Projects"

        return """
        TimeTracker Export
        Period: \(periodTitle)
        Project Filter: \(activeProject)
        Exported: \(dateStamp)

        \(rows.joined(separator: "\n\n"))
        """
    }

    private func rangeTitle(from startDate: Date, to endDate: Date) -> String {
        let formatter = DisplayFormatter.formatter(pattern: "dd.MM.yyyy")
        return "\(formatter.string(from: min(startDate, endDate))) - \(formatter.string(from: max(startDate, endDate)))"
    }

    private func rangeSlug(from startDate: Date?, to endDate: Date?) -> String {
        guard let startDate, let endDate else {
            return "custom-range"
        }

        let formatter = DisplayFormatter.formatter(pattern: "yyyy-MM-dd")
        return "\(formatter.string(from: min(startDate, endDate)))-to-\(formatter.string(from: max(startDate, endDate)))"
    }

    private func presentShareSheet(for fileURL: URL) {
        guard let contentView = NSApp.keyWindow?.contentView else {
            exportErrorMessage = "TimeTracker could not open the share menu."
            return
        }

        let picker = NSSharingServicePicker(items: [fileURL])
        let origin = NSRect(
            x: contentView.bounds.maxX - 120,
            y: contentView.bounds.maxY - 72,
            width: 44,
            height: 44
        )
        picker.show(relativeTo: origin, of: contentView, preferredEdge: .minY)
    }

    private func buildPDF(from report: String) throws -> Data {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.black
        ]
        let attributedText = NSAttributedString(string: report, attributes: attributes)
        let textRect = attributedText.boundingRect(
            with: NSSize(width: 523, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let reportHeight = max(842, ceil(textRect.height) + 72)
        let reportView = ExportReportView(
            frame: NSRect(x: 0, y: 0, width: 595, height: reportHeight),
            attributedText: attributedText
        )

        return reportView.dataWithPDF(inside: reportView.bounds)
    }

    private var dateStamp: String {
        DisplayFormatter.formatter(pattern: "yyyy-MM-dd-HHmm").string(from: Date())
    }
}

private struct ExportRangePickerSheet: View {
    let lastExportedRange: ClosedRange<Date>?
    let onCancel: () -> Void
    let onExport: (Date, Date) -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var displayedMonth: Date
    @State private var isChoosingEnd = false

    private let calendar = Calendar.current
    private let orange = Color(hex: "#F59E0B")

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
            AppTheme.primary.ignoresSafeArea()

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
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Text("Pick the exact days you want in the PDF.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var rangeSummary: some View {
        HStack {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.textSecondary)

            Text(rangeText)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .monospacedDigit()

            Spacer()

            Text(isChoosingEnd ? "Pick end" : "Pick start")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isChoosingEnd ? orange : AppTheme.textSecondary)
                .padding(.horizontal, AppTheme.spacingSM)
                .padding(.vertical, AppTheme.spacingXS)
                .background((isChoosingEnd ? orange : AppTheme.surfaceAlt).opacity(isChoosingEnd ? 0.22 : 1))
                .clipShape(Capsule())
        }
        .padding(AppTheme.spacingMD)
        .background(AppTheme.surfaceMuted)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
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
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    private var monthHeader: some View {
        HStack {
            Button(action: { moveMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthTitle)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Button(action: { moveMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        let symbols = reorderedWeekdaySymbols

        return HStack(spacing: AppTheme.spacingXS) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .bold))
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
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
            .buttonStyle(.plain)

            Button(action: { onExport(startDate, endDate) }) {
                Label("Export PDF", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
            .buttonStyle(.plain)
        }
    }

    private func dayButton(for date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let isCurrentMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let isEndpoint = calendar.isDate(day, inSameDayAs: startDate) || calendar.isDate(day, inSameDayAs: endDate)
        let isSelectedRange = day >= min(startDate, endDate) && day <= max(startDate, endDate)
        let wasExported = lastExportedRange.map { range in
            day >= calendar.startOfDay(for: range.lowerBound) && day <= calendar.startOfDay(for: range.upperBound)
        } ?? false

        return Button(action: { select(day) }) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 14, weight: isEndpoint ? .bold : .semibold, design: .rounded))
                .foregroundColor(dayTextColor(isCurrentMonth: isCurrentMonth, isEndpoint: isEndpoint))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(dayBackground(isEndpoint: isEndpoint, isSelectedRange: isSelectedRange, wasExported: wasExported))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(wasExported && !isEndpoint ? orange.opacity(0.65) : Color.clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func dayTextColor(isCurrentMonth: Bool, isEndpoint: Bool) -> Color {
        if isEndpoint {
            return AppTheme.primary
        }

        return isCurrentMonth ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.55)
    }

    private func dayBackground(isEndpoint: Bool, isSelectedRange: Bool, wasExported: Bool) -> Color {
        if isEndpoint {
            return AppTheme.accent
        }

        if isSelectedRange {
            return AppTheme.surfaceAlt
        }

        if wasExported {
            return orange.opacity(0.22)
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

private final class ExportReportView: NSView {
    private let attributedText: NSAttributedString

    override var isFlipped: Bool {
        true
    }

    init(frame frameRect: NSRect, attributedText: NSAttributedString) {
        self.attributedText = attributedText
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        dirtyRect.fill()
        attributedText.draw(in: NSRect(x: 36, y: 36, width: bounds.width - 72, height: bounds.height - 72))
    }
}
