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
    @Namespace private var displayModeNamespace
    @AppStorage("recordings_display_mode") private var displayModeRawValue = RecordingsDisplayMode.list.rawValue
    @AppStorage("last_exported_range_start") private var lastExportedRangeStart: Double = 0
    @AppStorage("last_exported_range_end") private var lastExportedRangeEnd: Double = 0
    private let contentWidth: CGFloat = 980

    var body: some View {
        ZStack {

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
                            RecordingsCalendarView(
                                viewModel: viewModel,
                                calendarMonth: $calendarMonth,
                                selectedDate: $selectedCalendarDate,
                                onEdit: { selectedEntry = $0 }
                            )
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
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacingSM) {
                    Text("Recordings")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    if !viewModel.entries.isEmpty {
                        Text(recordingsSummary)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

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
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.glassCircle())
                .disabled(viewModel.entries.isEmpty)
                .help("Export PDF")

                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.onAccent)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.glassCircle(tint: AppTheme.accent.opacity(0.92)))
                .help("Add Recording")
            }
            .glassGroup(spacing: 10)
            .padding(.bottom, 2)
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.top, AppTheme.spacingSM)
        .padding(.bottom, AppTheme.spacingMD)
    }

    private var recordingsSummary: String {
        let count = viewModel.entries.count
        return "\(count) recording\(count == 1 ? "" : "s") · \(DisplayFormatter.compactDuration(viewModel.totalDuration))"
    }

    private var displayModeToggle: some View {
        HStack(spacing: 2) {
            displayModeButton(.list)
            displayModeButton(.calendar)
        }
        .padding(4)
        .glassSurface(in: Capsule(style: .continuous))
    }

    private func displayModeButton(_ mode: RecordingsDisplayMode) -> some View {
        let isSelected = selectedDisplayMode == mode

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                displayModeRawValue = mode.rawValue
            }
        } label: {
            Image(systemName: mode.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? AppTheme.onAccent : AppTheme.textSecondary)
                .frame(width: 38, height: 32)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(AppTheme.accent)
                            .matchedGeometryEffect(id: "displayMode", in: displayModeNamespace)
                    }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .help(mode == .list ? "List view" : "Calendar view")
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingMD) {
            Spacer()

            Image(systemName: "clock")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 72, height: 72)
                .glassSurface(in: Circle())

            VStack(spacing: AppTheme.spacingXS) {
                Text("No recordings yet")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Text("Start the timer or add a recording by hand.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Button(action: { showingAddSheet = true }) {
                Label("Create Recording", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.onAccent)
                    .padding(.horizontal, AppTheme.spacingLG)
                    .frame(height: 40)
            }
            .buttonStyle(.glassCapsule(tint: AppTheme.accent.opacity(0.92)))
            .padding(.top, AppTheme.spacingXS)

            Spacer()
        }
    }

    private var entriesList: some View {
        List {
            ForEach(viewModel.daySections) { section in
                // Day headers are plain rows: pinned section headers draw an opaque bar over the glass.
                dayHeader(for: section)
                    .listRowInsets(EdgeInsets(top: AppTheme.spacingMD, leading: 0, bottom: 2, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

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
                        top: AppTheme.spacingXS,
                        leading: 0,
                        bottom: AppTheme.spacingXS,
                        trailing: 0
                    ))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity)
    }

    private func dayHeader(for section: EntryDaySection) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(formatSectionDate(section.day))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Text(DisplayFormatter.compactDuration(section.totalDuration))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal, AppTheme.spacingXS)
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

    private var lastExportedRange: ClosedRange<Date>? {
        guard lastExportedRangeStart > 0, lastExportedRangeEnd > 0 else {
            return nil
        }

        let start = Date(timeIntervalSince1970: min(lastExportedRangeStart, lastExportedRangeEnd))
        let end = Date(timeIntervalSince1970: max(lastExportedRangeStart, lastExportedRangeEnd))
        return start...end
    }

    private func exportEntries(from startDate: Date, to endDate: Date) {
        let exportEntries = viewModel.exportEntries(from: startDate, to: endDate)
        let periodTitle = RecordingsExporter.rangeTitle(from: startDate, to: endDate)

        guard !exportEntries.isEmpty else {
            exportErrorMessage = "There are no recordings in \(periodTitle.lowercased()) to export."
            return
        }

        do {
            let projectFilter = viewModel.selectedProjectFilterId.flatMap { viewModel.project(for: $0)?.name } ?? "All Projects"
            let fileURL = try RecordingsExporter.writePDF(
                for: exportEntries,
                from: startDate,
                to: endDate,
                projectFilter: projectFilter
            )
            let calendar = Calendar.current
            lastExportedRangeStart = calendar.startOfDay(for: min(startDate, endDate)).timeIntervalSince1970
            lastExportedRangeEnd = calendar.startOfDay(for: max(startDate, endDate)).timeIntervalSince1970
            presentShareSheet(for: fileURL)
        } catch {
            exportErrorMessage = "TimeTracker could not export those recordings: \(error.localizedDescription)"
        }
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

}
