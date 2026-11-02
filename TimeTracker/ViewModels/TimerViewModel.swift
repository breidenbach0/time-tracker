import Foundation

@MainActor
final class TimerViewModel: ObservableObject {
    static let shared = TimerViewModel()

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

    init() {
        loadWorkspace()
        checkRunningTimer()
    }

    func loadWorkspace() {
        projects = DatabaseManager.shared.fetchAllProjects()
        ensureValidSelectedProject()

        refreshAutoNameSuggestion()
    }

    func checkRunningTimer() {
        if let state = DatabaseManager.shared.getRunningTimerState(),
           projects.contains(where: { $0.id == state.projectId }) {
            entryName = state.name
            entryNotes = state.notes
            selectedProjectId = state.projectId
            startDate = state.startDate
            isRunning = true
        } else {
            DatabaseManager.shared.clearRunningTimerState()
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

        DatabaseManager.shared.saveRunningTimerState(
            name: entryName,
            notes: entryNotes,
            projectId: selectedProjectId,
            categoryId: nil,
            startDate: startDate
        )
    }

    func stopTimer() -> TimeEntry? {
        ensureValidSelectedProject()
        guard let selectedProjectId,
              projects.contains(where: { $0.id == selectedProjectId }) else {
            return nil
        }

        let entry = RecordingStore.shared.saveEntry(TimeEntry(
            name: entryName,
            notes: entryNotes,
            projectId: selectedProjectId,
            categoryId: nil,
            startDate: startDate,
            endDate: Date()
        ))
        DatabaseManager.shared.clearRunningTimerState()

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

        DatabaseManager.shared.saveRunningTimerState(
            name: entryName,
            notes: entryNotes,
            projectId: selectedProjectId,
            categoryId: nil,
            startDate: startDate
        )
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
            return DatabaseManager.shared.nextRecordingName(for: selectedProjectId)
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

        autoNameSuggestion = DatabaseManager.shared.nextRecordingName(for: selectedProjectId)
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
