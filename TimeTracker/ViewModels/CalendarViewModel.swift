import Foundation
import Combine
import SwiftUI

enum CalendarViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case list = "List"
}

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var viewMode: CalendarViewMode = .week
    @Published var entries: [TimeEntry] = []
    @Published var projects: [Project] = []
    @Published var categories: [Category] = []
    @Published var selectedProjectFilterId: Int64?

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadWorkspace()
        loadEntries()

        $selectedDate
            .sink { [weak self] _ in
                self?.loadEntries()
            }
            .store(in: &cancellables)
    }

    func loadWorkspace() {
        projects = DatabaseManager.shared.fetchAllProjects()
        categories = DatabaseManager.shared.fetchAllCategories()

        if let selectedProjectFilterId,
           !projects.contains(where: { $0.id == selectedProjectFilterId }) {
            self.selectedProjectFilterId = nil
        }
    }

    func loadEntries() {
        let calendar = Calendar.current

        switch viewMode {
        case .day:
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            entries = DatabaseManager.shared.fetchTimeEntries(from: startOfDay, to: endOfDay, projectFilterId: selectedProjectFilterId)

        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            entries = DatabaseManager.shared.fetchTimeEntries(from: startOfWeek, to: endOfWeek, projectFilterId: selectedProjectFilterId)

        case .month:
            let components = calendar.dateComponents([.year, .month], from: selectedDate)
            let startOfMonth = calendar.date(from: components)!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            entries = DatabaseManager.shared.fetchTimeEntries(from: startOfMonth, to: endOfMonth, projectFilterId: selectedProjectFilterId)

        case .list:
            entries = DatabaseManager.shared.fetchAllTimeEntries(projectFilterId: selectedProjectFilterId)
        }
    }

    func selectProjectFilter(_ projectId: Int64?) {
        selectedProjectFilterId = projectId
        loadEntries()
    }

    func category(for id: Int64?) -> Category? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    func project(for id: Int64) -> Project? {
        projects.first { $0.id == id }
    }

    func color(for entry: TimeEntry) -> Color {
        if let category = category(for: entry.categoryId) {
            return Color(hex: category.colorHex)
        }

        if let project = project(for: entry.projectId) {
            return Color(hex: project.colorHex)
        }

        return AppTheme.accentBlue
    }

    func dominantColor(for entries: [TimeEntry]) -> Color {
        guard let firstEntry = entries.first else {
            return AppTheme.accentBlue
        }
        return color(for: firstEntry)
    }

    func entries(for date: Date) -> [TimeEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    func totalDuration(for date: Date) -> TimeInterval {
        entries(for: date).reduce(0) { $0 + $1.duration }
    }

    func goToPrevious() {
        let calendar = Calendar.current
        switch viewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        case .list:
            break
        }
    }

    func goToNext() {
        let calendar = Calendar.current
        switch viewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        case .list:
            break
        }
    }

    func goToToday() {
        selectedDate = Date()
    }
}
