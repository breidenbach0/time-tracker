import Foundation

/// The projects and recordings every screen shows, kept in memory and saved through
/// `DatabaseManager`. Screens and view models observe it, so a change made anywhere (the main
/// window, the mini player, a sheet) shows up everywhere without re-reading the database.
@MainActor
final class WorkspaceStore: ObservableObject {
    static let shared = WorkspaceStore(database: .shared)

    /// Oldest first, the order they were created in.
    @Published private(set) var projects: [Project] = []
    /// Every recording, newest first.
    @Published private(set) var entries: [TimeEntry] = []

    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
        projects = database.fetchAllProjects()
        entries = database.fetchAllTimeEntries()
    }

    func project(withId projectId: Int64) -> Project? {
        projects.first { $0.id == projectId }
    }

    /// Recordings in one project, or all of them for `nil`, newest first.
    func entries(inProject projectId: Int64?) -> [TimeEntry] {
        guard let projectId else { return entries }
        return entries.filter { $0.projectId == projectId }
    }

    // MARK: - Projects

    /// Adds a new project or saves changes to an existing one. Nil if it couldn't be saved.
    @discardableResult
    func saveProject(_ project: Project) -> Project? {
        var saved = project
        saved.updatedAt = Date()

        if let projectId = saved.id {
            guard database.updateProject(saved) else { return nil }
            if let index = projects.firstIndex(where: { $0.id == projectId }) {
                projects[index] = saved
            }
        } else {
            guard let projectId = database.insertProject(saved) else { return nil }
            saved.id = projectId
            projects.append(saved)
        }

        return saved
    }

    /// Deletes a project and every recording in it. False if nothing was deleted.
    @discardableResult
    func deleteProject(_ project: Project) -> Bool {
        guard let projectId = project.id, database.deleteProjectAndEntries(withId: projectId) else {
            return false
        }

        projects.removeAll { $0.id == projectId }
        entries.removeAll { $0.projectId == projectId }
        return true
    }

    // MARK: - Recordings

    /// Adds or updates a recording. Trims its name and notes, and gives it a name if it has none.
    @discardableResult
    func saveEntry(_ entry: TimeEntry) -> TimeEntry {
        var stored = entry
        let trimmedName = stored.name.trimmingCharacters(in: .whitespacesAndNewlines)
        stored.name = trimmedName.isEmpty ? nextRecordingName(for: stored.projectId) : trimmedName
        stored.notes = stored.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        stored.updatedAt = Date()

        if let entryId = stored.id {
            guard database.updateTimeEntry(stored) else { return stored }
            entries.removeAll { $0.id == entryId }
        } else {
            guard let entryId = database.insertTimeEntry(stored) else { return stored }
            stored.id = entryId
        }

        // Keep newest first: after any newer ones, and after others that started at the same time.
        let index = entries.firstIndex { $0.startDate < stored.startDate } ?? entries.count
        entries.insert(stored, at: index)
        return stored
    }

    func deleteEntry(_ entry: TimeEntry) {
        guard let entryId = entry.id, database.deleteTimeEntry(entry) else { return }
        entries.removeAll { $0.id == entryId }
    }

    /// A name no recording in the project has yet, or any name once they're all taken.
    func nextRecordingName(for projectId: Int64) -> String {
        let candidates = database.recordingNameCandidates
        guard !candidates.isEmpty else { return "Recording" }

        let usedNames = Set(
            entries.lazy
                .filter { $0.projectId == projectId }
                .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        let availableNames = candidates.filter { !usedNames.contains($0) }
        return availableNames.randomElement() ?? candidates.randomElement() ?? "Recording"
    }

    // MARK: - Running Timer

    var runningTimer: RunningTimerState? {
        database.runningTimer()
    }

    func saveRunningTimer(_ state: RunningTimerState) {
        database.saveRunningTimer(state)
    }

    func clearRunningTimer() {
        database.clearRunningTimer()
    }
}
