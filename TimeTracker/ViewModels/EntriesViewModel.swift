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

struct EntryDaySection: Identifiable {
    let day: Date
    let entries: [TimeEntry]
    let totalDuration: TimeInterval

    var id: Date { day }
}

@MainActor
final class EntriesViewModel: ObservableObject {
    @Published var entries: [TimeEntry] = [] {
        didSet { rebuildDayIndex() }
    }
    @Published var projects: [Project] = [] {
        didSet {
            projectsByID = Dictionary(
                projects.compactMap { project in project.id.map { ($0, project) } },
                uniquingKeysWith: { first, _ in first }
            )
        }
    }
    @Published var selectedProjectFilterId: Int64?

    /// Derived once per load instead of on every render.
    private(set) var daySections: [EntryDaySection] = []
    private(set) var entriesByDay: [Date: [TimeEntry]] = [:]
    private(set) var totalDuration: TimeInterval = 0
    private var projectsByID: [Int64: Project] = [:]

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
        projectsByID[id]
    }

    func entries(on day: Date) -> [TimeEntry] {
        entriesByDay[Calendar.current.startOfDay(for: day)] ?? []
    }

    private func rebuildDayIndex() {
        let calendar = Calendar.current
        var sections: [EntryDaySection] = []
        var byDay: [Date: [TimeEntry]] = [:]
        var currentDay: Date?
        var currentEntries: [TimeEntry] = []
        var total: TimeInterval = 0

        func closeSection() {
            guard let currentDay, !currentEntries.isEmpty else { return }
            sections.append(EntryDaySection(
                day: currentDay,
                entries: currentEntries,
                totalDuration: currentEntries.reduce(0) { $0 + $1.duration }
            ))
        }

        // Entries arrive newest first, so one pass yields sections in display order.
        for entry in entries {
            let day = calendar.startOfDay(for: entry.startDate)
            byDay[day, default: []].append(entry)
            total += entry.duration

            if day != currentDay {
                closeSection()
                currentDay = day
                currentEntries = []
            }
            currentEntries.append(entry)
        }
        closeSection()

        daySections = sections
        entriesByDay = byDay
        totalDuration = total
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
