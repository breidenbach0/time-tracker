import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedEntry: TimeEntry?

    var body: some View {
        ZStack {
            AppTheme.primary.ignoresSafeArea()

            VStack(spacing: 0) {
                projectFilters
                viewModePicker

                dateNavigator

                contentView
            }
        }
        .sheet(item: $selectedEntry) { entry in
            AddEntrySheet(editingEntry: entry) {
                viewModel.loadWorkspace()
                viewModel.loadEntries()
            }
        }
        .onAppear {
            viewModel.loadWorkspace()
            viewModel.loadEntries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workspaceDidChange)) { _ in
            viewModel.loadWorkspace()
            viewModel.loadEntries()
        }
    }

    private var projectFilters: some View {
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
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.top, AppTheme.spacingMD)
        }
    }

    private var viewModePicker: some View {
        Picker("View Mode", selection: $viewModel.viewMode) {
            ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.top, AppTheme.spacingSM)
        .onChange(of: viewModel.viewMode) { _ in
            viewModel.loadEntries()
        }
    }

    private var dateNavigator: some View {
        HStack {
            Button(action: viewModel.goToPrevious) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            Button(action: viewModel.goToToday) {
                Text(titleText)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            Button(action: viewModel.goToNext) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.vertical, AppTheme.spacingMD)
    }

    private var titleText: String {
        let formatter = DateFormatter()
        switch viewModel.viewMode {
        case .day:
            formatter.dateFormat = "EEEE, MMM d"
        case .week:
            formatter.dateFormat = "MMM d"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        case .list:
            formatter.dateFormat = "MMMM yyyy"
        }
        return formatter.string(from: viewModel.selectedDate)
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.viewMode {
        case .day:
            CalendarDayView(viewModel: viewModel, selectedEntry: $selectedEntry)
        case .week:
            CalendarWeekView(viewModel: viewModel, selectedEntry: $selectedEntry)
        case .month:
            CalendarMonthView(viewModel: viewModel, selectedEntry: $selectedEntry)
        case .list:
            CalendarListView(viewModel: viewModel, selectedEntry: $selectedEntry)
        }
    }
}
