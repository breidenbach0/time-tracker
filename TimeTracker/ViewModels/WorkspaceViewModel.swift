import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var recordingsCount = 0
    @Published var errorMessage: String?

    init() {
        loadData()
    }

    func loadData() {
        projects = DatabaseManager.shared.fetchAllProjects()
        recordingsCount = DatabaseManager.shared.fetchAllTimeEntries().count
    }

    func saveProject(_ project: Project) {
        if project.id == nil {
            _ = DatabaseManager.shared.insertProject(project)
        } else {
            DatabaseManager.shared.updateProject(project)
        }

        loadData()
    }

    func updateProjectColor(_ project: Project, to colorHex: String) {
        guard colorHex != project.colorHex else { return }

        var updatedProject = project
        updatedProject.colorHex = colorHex
        updatedProject.updatedAt = Date()
        DatabaseManager.shared.updateProject(updatedProject)
        loadData()
    }

    func deleteProject(_ project: Project) {
        guard let projectIdentifier = project.id else {
            return
        }

        let entriesInProject = DatabaseManager.shared.fetchAllTimeEntries(projectFilterId: projectIdentifier)
        for entry in entriesInProject {
            RecordingStore.shared.deleteEntry(entry)
        }

        DatabaseManager.shared.deleteProject(project)

        if DatabaseManager.shared.fetchProject(withId: projectIdentifier) != nil {
            errorMessage = "The project could not be deleted. Try again after deleting active recordings."
        }

        loadData()
    }
}
