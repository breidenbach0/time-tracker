import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var errorMessage: String?

    init() {
        loadData()
    }

    func loadData() {
        projects = DatabaseManager.shared.fetchAllProjects()
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

        // One statement and one change notification instead of one per recording.
        DatabaseManager.shared.deleteTimeEntries(inProjectWithId: projectIdentifier)

        DatabaseManager.shared.deleteProject(project)

        if DatabaseManager.shared.fetchProject(withId: projectIdentifier) != nil {
            errorMessage = "The project could not be deleted. Try again after deleting active recordings."
        }

        loadData()
    }
}
