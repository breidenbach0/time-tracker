import Combine
import Foundation

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

    private let store: WorkspaceStore
    private var cancellables = Set<AnyCancellable>()

    init(store: WorkspaceStore = .shared) {
        self.store = store
        apply(projects: store.projects, entries: store.entries)

        // The store publishes before it changes, so use the values it hands over.
        Publishers.CombineLatest(store.$projects, store.$entries)
            .dropFirst()
            .sink { [weak self] projects, entries in
                self?.apply(projects: projects, entries: entries)
            }
            .store(in: &cancellables)
    }

    func selectProjectFilter(_ projectId: Int64?) {
        selectedProjectFilterId = projectId
        apply(projects: store.projects, entries: store.entries)
    }

    func deleteEntry(_ entry: TimeEntry) {
        store.deleteEntry(entry)
    }

    private func apply(projects: [Project], entries allEntries: [TimeEntry]) {
        self.projects = projects

        if let selectedProjectFilterId,
           !projects.contains(where: { $0.id == selectedProjectFilterId }) {
            self.selectedProjectFilterId = nil
        }

        if let selectedProjectFilterId {
            entries = allEntries.filter { $0.projectId == selectedProjectFilterId }
        } else {
            entries = allEntries
        }
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



    func exportEntries(from startDate: Date, to endDate: Date) -> [TimeEntry] {
        let calendar = Calendar.current
        let lowerBound = calendar.startOfDay(for: min(startDate, endDate))
        let upperDay = calendar.startOfDay(for: max(startDate, endDate))
        let upperBound = calendar.date(byAdding: .day, value: 1, to: upperDay) ?? upperDay

        return entries.filter { entry in
            entry.startDate >= lowerBound && entry.startDate < upperBound
        }
    }

}
