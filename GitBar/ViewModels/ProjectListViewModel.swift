import Foundation
import Combine

/// ViewModel for managing the project list sidebar
@MainActor
class ProjectListViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var isAutoRefreshEnabled = true

    private let discoveryService: ClaudeProjectDiscoveryService
    private let gitService: GitService
    private var autoRefreshTask: Task<Void, Never>?

    /// Refresh interval for all project indicators (60 seconds)
    private let autoRefreshInterval: TimeInterval = 60

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

    // MARK: - Auto-Refresh

    /// Starts the auto-refresh timer for all project indicators
    func startAutoRefresh() {
        stopAutoRefresh()
        guard isAutoRefreshEnabled else { return }

        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(autoRefreshInterval * 1_000_000_000))
                guard !Task.isCancelled, isAutoRefreshEnabled else { break }
                await refreshStatusSilently()
            }
        }
    }

    /// Stops the auto-refresh timer
    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    /// Refreshes status for all projects without disrupting user interaction
    private func refreshStatusSilently() async {
        for index in projects.indices {
            guard !Task.isCancelled else { break }
            projects[index].hasUncommittedChanges = await checkForUncommittedChanges(at: projects[index].path)
        }
    }

    deinit {
        autoRefreshTask?.cancel()
    }
}
