import Foundation

enum ExportPeriod: String, CaseIterable, Identifiable {
    case lastWeek
    case lastMonth
    case lastThreeMonths

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lastWeek:
            return "Last Week"
        case .lastMonth:
            return "Last Month"
        case .lastThreeMonths:
            return "Last 3 Months"
        }
    }
}

@MainActor
final class EntriesViewModel: ObservableObject {
    @Published var entries: [TimeEntry] = []
    @Published var projects: [Project] = []
    @Published var selectedProjectFilterId: Int64?

    init() {
        loadWorkspace()
        loadEntries()
    }

    func loadWorkspace() {
        projects = DatabaseManager.shared.fetchAllProjects()

        if let selectedProjectFilterId,
           !projects.contains(where: { $0.id == selectedProjectFilterId }) {
            self.selectedProjectFilterId = nil
        }
    }

    func loadEntries() {
        entries = DatabaseManager.shared.fetchAllTimeEntries(projectFilterId: selectedProjectFilterId)
    }

    func selectProjectFilter(_ projectId: Int64?) {
        selectedProjectFilterId = projectId
        loadEntries()
    }

    func deleteEntry(_ entry: TimeEntry) {
        RecordingStore.shared.deleteEntry(entry)
        loadEntries()
    }

    func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            RecordingStore.shared.deleteEntry(entry)
        }
        loadEntries()
    }

    func project(for id: Int64) -> Project? {
        projects.first { $0.id == id }
    }

    func saveEntry(_ entry: TimeEntry) {
        _ = RecordingStore.shared.saveEntry(entry)
        loadEntries()
    }

    func exportEntries(from startDate: Date, to endDate: Date) -> [TimeEntry] {
        let calendar = Calendar.current
        let lowerBound = calendar.startOfDay(for: min(startDate, endDate))
        let upperDay = calendar.startOfDay(for: max(startDate, endDate))
        let upperBound = calendar.date(byAdding: .day, value: 1, to: upperDay) ?? upperDay

        return entries.filter { entry in
            entry.startDate >= lowerBound && entry.startDate < upperBound
        }
    }

    func exportEntries(for period: ExportPeriod) -> [TimeEntry] {
        let lowerBound = startDate(for: period)
        return entries.filter { $0.startDate >= lowerBound }
    }

    private func startDate(for period: ExportPeriod) -> Date {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .lastWeek:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .lastThreeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now) ?? now
        }
    }
}
