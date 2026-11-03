import Combine
import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published var errorMessage: String?

    private let store: WorkspaceStore
    private var cancellables = Set<AnyCancellable>()

    init(store: WorkspaceStore = .shared) {
        self.store = store
        projects = store.projects

        store.$projects
            .dropFirst()
            .sink { [weak self] projects in
                self?.projects = projects
            }
            .store(in: &cancellables)
    }

    func saveProject(_ project: Project) {
        if store.saveProject(project) == nil {
            errorMessage = "The project could not be saved. Try again."
        }
    }

    func deleteProject(_ project: Project) {
        if !store.deleteProject(project) {
            errorMessage = "The project could not be deleted. Try again."
        }
    }
}
