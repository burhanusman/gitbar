import Foundation
import Combine

/// ViewModel for managing the project list sidebar
@MainActor
class ProjectListViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?

    private let discoveryService: ClaudeProjectDiscoveryService
    private let gitService: GitService

    init(discoveryService: ClaudeProjectDiscoveryService = ClaudeProjectDiscoveryService(),
         gitService: GitService = GitService()) {
        self.discoveryService = discoveryService
        self.gitService = gitService
    }

    /// Loads projects and checks their git status
    func loadProjects() {
        let discoveredProjects = discoveryService.discoverProjects()

        Task {
            var loadedProjects: [Project] = []

            for claudeProject in discoveredProjects {
                let hasChanges = await checkForUncommittedChanges(at: claudeProject.path)
                loadedProjects.append(Project(from: claudeProject, hasUncommittedChanges: hasChanges))
            }

            projects = loadedProjects.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    /// Selects a project
    func selectProject(_ project: Project) {
        selectedProject = project
    }

    /// Checks if a Git repository has uncommitted changes using GitService
    private func checkForUncommittedChanges(at path: String) async -> Bool {
        do {
            return try await gitService.hasUncommittedChanges(at: path)
        } catch {
            return false
        }
    }

    /// Refreshes the git status for all projects
    func refreshStatus() {
        Task {
            for index in projects.indices {
                projects[index].hasUncommittedChanges = await checkForUncommittedChanges(at: projects[index].path)
            }
        }
    }
}
