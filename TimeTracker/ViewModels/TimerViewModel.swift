import Combine
import Foundation

@MainActor
final class TimerViewModel: ObservableObject {
    static let shared = TimerViewModel(store: .shared)

    @Published var isRunning: Bool = false
    @Published var entryName: String = ""
    @Published var entryNotes: String = ""
    @Published var selectedProjectId: Int64?
    @Published var startDate: Date = Date()
    @Published var projects: [Project] = []
    @Published private(set) var autoNameSuggestion: String = "Recording"

    /// Computed on demand. Views that show a live clock wrap it in a `TimelineView`,
    /// so the model no longer publishes a change (and re-renders every window) each second.
    var elapsedTime: TimeInterval {
        isRunning ? max(0, Date().timeIntervalSince(startDate)) : 0
    }

    private let store: WorkspaceStore
    private var cancellables = Set<AnyCancellable>()

    init(store: WorkspaceStore) {
        self.store = store
        projects = store.projects
        ensureValidSelectedProject()
        refreshAutoNameSuggestion()
        restoreRunningTimer()

        // The store publishes before it changes, so use the new value it hands over.
        store.$projects
            .dropFirst()
            .sink { [weak self] projects in
                guard let self else { return }
                self.projects = projects
                self.ensureValidSelectedProject()
                self.refreshAutoNameSuggestion()
            }
            .store(in: &cancellables)

        store.$entries
            .dropFirst()
            .sink { [weak self] entries in
                self?.refreshAutoNameSuggestionIfTaken(in: entries)
            }
            .store(in: &cancellables)
    }

    private func restoreRunningTimer() {
        if let state = store.runningTimer,
           projects.contains(where: { $0.id == state.projectId }) {
            entryName = state.name
            entryNotes = state.notes
            selectedProjectId = state.projectId
            startDate = state.startDate
            isRunning = true
        } else {
            store.clearRunningTimer()
        }
    }

    func startTimer() {
        ensureValidSelectedProject()
        guard let selectedProjectId,
              projects.contains(where: { $0.id == selectedProjectId }),
              !isRunning else {
            return
        }

        let trimmedName = entryName.trimmingCharacters(in: .whitespacesAndNewlines)
        entryName = trimmedName.isEmpty
            ? autoNameSuggestion
            : trimmedName

        startDate = Date()
        isRunning = true

        store.saveRunningTimer(RunningTimerState(
            name: entryName,
            notes: entryNotes,
            projectId: selectedProjectId,
            startDate: startDate
        ))
    }

    func stopTimer() -> TimeEntry? {
        ensureValidSelectedProject()
        guard let selectedProjectId,
              projects.contains(where: { $0.id == selectedProjectId }) else {
            return nil
        }

        let entry = store.saveEntry(TimeEntry(
            name: entryName,
            notes: entryNotes,
            projectId: selectedProjectId,
            categoryId: nil,
            startDate: startDate,
            endDate: Date()
        ))
        store.clearRunningTimer()

        isRunning = false
        entryName = ""
        entryNotes = ""
        refreshAutoNameSuggestion()

        return entry
    }

    func selectProject(_ projectId: Int64?) {
        selectedProjectId = projectId
        ensureValidSelectedProject()
        persistSelectedProject()
        refreshAutoNameSuggestion()
        persistRunningTimerStateIfNeeded()
    }

    func persistRunningTimerStateIfNeeded() {
        guard isRunning, let selectedProjectId else { return }

        store.saveRunningTimer(RunningTimerState(
            name: entryName,
            notes: entryNotes,
            projectId: selectedProjectId,
            startDate: startDate
        ))
    }

    var formattedElapsedTime: String {
        Self.formatClock(elapsedTime)
    }

    func formattedElapsedTime(at date: Date) -> String {
        guard isRunning else { return Self.formatClock(0) }
        return Self.formatClock(date.timeIntervalSince(startDate))
    }

    static func formatClock(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var selectedProject: Project? {
        guard let selectedProjectId else { return nil }
        return projects.first { $0.id == selectedProjectId }
    }

    func project(for id: Int64) -> Project? {
        projects.first { $0.id == id }
    }

    var canStartTimer: Bool {
        selectedProjectId != nil
    }

    var recordingPreviewName: String {
        let trimmedName = entryName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedName.isEmpty {
            return trimmedName
        }

        guard let selectedProjectId else {
            return "Recording"
        }

        if autoNameSuggestion == "Recording" {
            return store.nextRecordingName(for: selectedProjectId)
        }

        return autoNameSuggestion
    }

    private var persistedSelectedProjectId: Int64? {
        guard UserDefaults.standard.object(forKey: "selected_project_id") != nil else {
            return nil
        }

        return Int64(UserDefaults.standard.integer(forKey: "selected_project_id"))
    }

    private func persistSelectedProject() {
        if let selectedProjectId {
            UserDefaults.standard.set(selectedProjectId, forKey: "selected_project_id")
        } else {
            UserDefaults.standard.removeObject(forKey: "selected_project_id")
        }
    }

    private func refreshAutoNameSuggestion() {
        guard let selectedProjectId else {
            autoNameSuggestion = "Recording"
            return
        }

        autoNameSuggestion = store.nextRecordingName(for: selectedProjectId)
    }

    /// Picks a new suggestion only when a recording now uses the current one, so the
    /// placeholder doesn't change under the user for unrelated edits.
    private func refreshAutoNameSuggestionIfTaken(in entries: [TimeEntry]) {
        guard let selectedProjectId else { return }
        let isTaken = entries.contains {
            $0.projectId == selectedProjectId
                && $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == autoNameSuggestion
        }
        if isTaken {
            refreshAutoNameSuggestion()
        }
    }

    private func ensureValidSelectedProject() {
        let validProjectIDs = Set(projects.compactMap(\.id))

        if let selectedProjectId, validProjectIDs.contains(selectedProjectId) {
            persistSelectedProject()
            return
        }

        if let persistedSelectedProjectId, validProjectIDs.contains(persistedSelectedProjectId) {
            selectedProjectId = persistedSelectedProjectId
        } else {
            selectedProjectId = projects.first?.id
        }

        persistSelectedProject()
    }
}
