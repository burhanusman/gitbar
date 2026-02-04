import Foundation
import Combine

/// A collapsible group of projects shown in the sidebar
struct ProjectSection: Identifiable, Equatable {
    let id: String
    let title: String
    var isExpanded: Bool
    var projects: [Project]
}

/// ViewModel for managing the project list sidebar
@MainActor
class ProjectListViewModel: ObservableObject {
    @Published var sections: [ProjectSection] = []
    @Published var selectedProject: Project?
    @Published var isAutoRefreshEnabled = true
    @Published var sortMode: ProjectSortMode = SettingsService.shared.projectSortMode
    @Published var expandedWorktreeProjects: Set<String> = []
    @Published var selectedWorktreePath: String?

    private let discoveryService: ClaudeProjectDiscoveryService
    private let gitService: GitService
    private var autoRefreshTask: Task<Void, Never>?
    private var loadProjectsTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    /// Refresh interval for all project indicators (60 seconds)
    private let autoRefreshInterval: TimeInterval = 60

    init(discoveryService: ClaudeProjectDiscoveryService = ClaudeProjectDiscoveryService(),
         gitService: GitService = GitService()) {
        self.discoveryService = discoveryService
        self.gitService = gitService

        NotificationCenter.default.publisher(for: .repoFoldersDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadProjects()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .projectSortModeDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.sortMode = SettingsService.shared.projectSortMode
                self?.resortSections()
            }
            .store(in: &cancellables)
    }

    /// Toggles between alphabetical and recent sort modes
    func toggleSortMode() {
        let newMode: ProjectSortMode = sortMode == .alphabetical ? .recent : .alphabetical
        SettingsService.shared.projectSortMode = newMode
    }

    /// Re-sorts all sections based on current sort mode
    private func resortSections() {
        for i in sections.indices {
            sections[i].projects = sortProjects(sections[i].projects)
        }
    }

    /// Sorts projects based on current sort mode
    private func sortProjects(_ projects: [Project]) -> [Project] {
        switch sortMode {
        case .alphabetical:
            return projects.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .recent:
            return projects.sorted { p1, p2 in
                // Projects with activity come first, sorted by most recent
                switch (p1.lastActivityDate, p2.lastActivityDate) {
                case let (d1?, d2?):
                    return d1 > d2
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                case (nil, nil):
                    return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending
                }
            }
        }
    }

    /// Loads projects and checks their git status
    func loadProjects() {
        loadProjectsTask?.cancel()

        let previousExpansion = Dictionary(uniqueKeysWithValues: sections.map { ($0.id, $0.isExpanded) })
        // Use current selection, or fall back to persisted last selection
        let previouslySelectedPath = selectedProject?.path ?? SettingsService.shared.lastSelectedProjectPath
        let repoFolders = SettingsService.shared.repoFolders

        // Capture references needed for background work
        let discoveryService = self.discoveryService

        loadProjectsTask = Task {
            // Phase 1: Discover projects off the main thread (file I/O)
            let (newSections, _) = await Task.detached(priority: .userInitiated) {
                let discoveredProjects = discoveryService.discoverProjects()

                var newSections: [ProjectSection] = []
                var allDiscoveredPaths: Set<String> = []

                // Separate Claude and Codex projects
                let claudeProjects = discoveredProjects.filter { $0.source == .claude }
                let codexProjects = discoveredProjects.filter { $0.source == .codex }

                // Track paths to detect duplicates - prefer Claude over Codex
                var pathToSource: [String: ProjectSource] = [:]
                for project in claudeProjects {
                    pathToSource[project.path] = .claude
                }
                for project in codexProjects where pathToSource[project.path] == nil {
                    pathToSource[project.path] = .codex
                }

                // Claude section
                var loadedClaudeProjects: [Project] = []
                for claudeProject in claudeProjects {
                    guard pathToSource[claudeProject.path] == .claude else { continue }
                    allDiscoveredPaths.insert(claudeProject.path)
                    loadedClaudeProjects.append(Project(from: claudeProject, hasUncommittedChanges: false, commitActivity: .empty, lastActivityDate: nil))
                }

                if !loadedClaudeProjects.isEmpty {
                    newSections.append(
                        ProjectSection(
                            id: "claude",
                            title: "Claude",
                            isExpanded: previousExpansion["claude"] ?? true,
                            projects: loadedClaudeProjects
                        )
                    )
                }

                // Codex section
                var loadedCodexProjects: [Project] = []
                for codexProject in codexProjects {
                    guard pathToSource[codexProject.path] == .codex else { continue }
                    allDiscoveredPaths.insert(codexProject.path)
                    loadedCodexProjects.append(Project(from: codexProject, hasUncommittedChanges: false, commitActivity: .empty, lastActivityDate: nil))
                }

                if !loadedCodexProjects.isEmpty {
                    newSections.append(
                        ProjectSection(
                            id: "codex",
                            title: "Codex",
                            isExpanded: previousExpansion["codex"] ?? true,
                            projects: loadedCodexProjects
                        )
                    )
                }

                // User folders
                for folderPath in repoFolders {
                    let repoPaths = ProjectListViewModel.discoverGitRepositories(in: folderPath).filter { !allDiscoveredPaths.contains($0) }
                    var loadedFolderProjects: [Project] = []

                    for repoPath in repoPaths {
                        let repoName = URL(fileURLWithPath: repoPath).lastPathComponent
                        loadedFolderProjects.append(Project(name: repoName, path: repoPath, source: .folder, hasUncommittedChanges: false, commitActivity: .empty, lastActivityDate: nil))
                    }

                    let sectionId = "folder:\(folderPath)"
                    newSections.append(
                        ProjectSection(
                            id: sectionId,
                            title: URL(fileURLWithPath: folderPath).lastPathComponent,
                            isExpanded: previousExpansion[sectionId] ?? true,
                            projects: loadedFolderProjects
                        )
                    )
                }

                return (newSections, allDiscoveredPaths)
            }.value

            guard !Task.isCancelled else { return }

            // Sort and update UI on main thread
            var sortedSections = newSections
            for i in sortedSections.indices {
                sortedSections[i].projects = sortProjects(sortedSections[i].projects)
            }
            sections = sortedSections

            // Preserve selection if possible
            if let previouslySelectedPath,
               let project = findProject(withPath: previouslySelectedPath, in: sortedSections) {
                selectedProject = project
            }

            // Phase 2: Load git status in background and update projects as results come in
            await loadGitStatusForAllProjects()
        }
    }

    /// Loads git status for all projects in background and updates them incrementally
    private func loadGitStatusForAllProjects() async {
        for sectionIndex in sections.indices {
            for projectIndex in sections[sectionIndex].projects.indices {
                guard !Task.isCancelled else { return }
                let path = sections[sectionIndex].projects[projectIndex].path

                // Load all git info concurrently for this project
                async let hasChanges = checkForUncommittedChanges(at: path)
                async let activity = getCommitActivity(at: path)
                async let lastActivity = getLastCommitDate(at: path)
                async let worktreeInfos = loadWorktreeInfo(for: path)

                // Update the project with loaded values
                let (changes, act, lastAct, wts) = await (hasChanges, activity, lastActivity, worktreeInfos)
                sections[sectionIndex].projects[projectIndex].hasUncommittedChanges = changes
                sections[sectionIndex].projects[projectIndex].commitActivity = act
                sections[sectionIndex].projects[projectIndex].lastActivityDate = lastAct
                sections[sectionIndex].projects[projectIndex].worktrees = wts
            }
        }

        // Re-sort sections after all git status is loaded if in recent mode
        if sortMode == .recent {
            resortSections()
        }
    }

    /// Loads worktree info for a project, including uncommitted changes per worktree
    private func loadWorktreeInfo(for projectPath: String) async -> [WorktreeInfo] {
        do {
            let worktrees = try await gitService.getWorktrees(at: projectPath)
            guard worktrees.count > 1 else { return [] }

            var infos: [WorktreeInfo] = []
            for (index, wt) in worktrees.enumerated() {
                let hasChanges: Bool
                do {
                    hasChanges = try await gitService.hasUncommittedChanges(at: wt.path)
                } catch {
                    hasChanges = false
                }
                let agentLabel = SettingsService.shared.agentLabel(forWorktreePath: wt.path)
                infos.append(WorktreeInfo(
                    path: wt.path,
                    branch: wt.branch,
                    head: wt.head,
                    isDetached: wt.isDetached,
                    isMain: index == 0,
                    hasUncommittedChanges: hasChanges,
                    agentLabel: agentLabel
                ))
            }
            return infos
        } catch {
            return []
        }
    }

    /// Selects a project and persists the selection
    func selectProject(_ project: Project) {
        selectedProject = project
        SettingsService.shared.lastSelectedProjectPath = project.path
        // Reset worktree selection to the project's active worktree or nil
        selectedWorktreePath = project.activeWorktreePath
        SettingsService.shared.lastSelectedWorktreePath = selectedWorktreePath
    }

    /// Selects a specific worktree within a project
    func selectWorktree(_ worktree: WorktreeInfo, in project: Project) {
        selectedWorktreePath = worktree.path
        SettingsService.shared.lastSelectedWorktreePath = worktree.path

        // Update the project's activeWorktreePath
        if let sectionIndex = sections.firstIndex(where: { $0.projects.contains(where: { $0.id == project.id }) }),
           let projectIndex = sections[sectionIndex].projects.firstIndex(where: { $0.id == project.id }) {
            sections[sectionIndex].projects[projectIndex].activeWorktreePath = worktree.path
        }

        // Also select the project if not already selected
        if selectedProject?.id != project.id {
            selectedProject = project
            SettingsService.shared.lastSelectedProjectPath = project.path
        }
    }

    /// Toggles worktree expansion for a project
    func toggleWorktreeExpansion(for projectId: String) {
        if expandedWorktreeProjects.contains(projectId) {
            expandedWorktreeProjects.remove(projectId)
        } else {
            expandedWorktreeProjects.insert(projectId)
        }
    }

    /// Returns a flat list of all visible projects (from expanded sections only)
    func allVisibleProjects(filteredSections: [ProjectSection]? = nil) -> [Project] {
        let sectionsToUse = filteredSections ?? sections
        return sectionsToUse.flatMap { section in
            section.isExpanded ? section.projects : []
        }
    }

    /// Selects the next project in the list (keyboard navigation)
    func selectNextProject(filteredSections: [ProjectSection]? = nil) {
        let visibleProjects = allVisibleProjects(filteredSections: filteredSections)
        guard !visibleProjects.isEmpty else { return }

        if let currentProject = selectedProject,
           let currentIndex = visibleProjects.firstIndex(where: { $0.id == currentProject.id }) {
            let nextIndex = min(currentIndex + 1, visibleProjects.count - 1)
            selectProject(visibleProjects[nextIndex])
        } else {
            // No selection, select first
            selectProject(visibleProjects[0])
        }
    }

    /// Selects the previous project in the list (keyboard navigation)
    func selectPreviousProject(filteredSections: [ProjectSection]? = nil) {
        let visibleProjects = allVisibleProjects(filteredSections: filteredSections)
        guard !visibleProjects.isEmpty else { return }

        if let currentProject = selectedProject,
           let currentIndex = visibleProjects.firstIndex(where: { $0.id == currentProject.id }) {
            let prevIndex = max(currentIndex - 1, 0)
            selectProject(visibleProjects[prevIndex])
        } else {
            // No selection, select last
            selectProject(visibleProjects[visibleProjects.count - 1])
        }
    }

    /// Checks if a Git repository has uncommitted changes using GitService
    private func checkForUncommittedChanges(at path: String) async -> Bool {
        do {
            return try await gitService.hasUncommittedChanges(at: path)
        } catch {
            return false
        }
    }

    /// Gets commit activity for a repository
    private func getCommitActivity(at path: String) async -> CommitActivity {
        do {
            let activityDict = try await gitService.getCommitActivity(at: path, days: 30)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // Convert dictionary to array (index 0 = today, index 1 = yesterday, etc.)
            var dailyCounts: [Int] = []
            for dayOffset in 0..<30 {
                if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                    let dayStart = calendar.startOfDay(for: date)
                    dailyCounts.append(activityDict[dayStart] ?? 0)
                }
            }

            return CommitActivity(dailyCounts: dailyCounts)
        } catch {
            return .empty
        }
    }

    /// Gets the last commit date for a repository
    private func getLastCommitDate(at path: String) async -> Date? {
        do {
            return try await gitService.getLastCommitDate(at: path)
        } catch {
            return nil
        }
    }

    private func findProject(withPath path: String, in sections: [ProjectSection]) -> Project? {
        for section in sections {
            if let project = section.projects.first(where: { $0.path == path }) {
                return project
            }
        }
        return nil
    }

    nonisolated private static func discoverGitRepositories(in folderPath: String, maxDepth: Int = 4) -> [String] {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: folderPath).standardizedFileURL

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return []
        }

        let excludedDirectoryNames: Set<String> = [
            ".git",
            "node_modules",
            "Pods",
            "DerivedData",
            "Carthage",
            ".swiftpm",
            ".build",
            "build",
            "dist"
        ]

        var repos: Set<String> = []

        // If the selected folder itself is a repo, include it.
        if fileManager.fileExists(atPath: rootURL.appendingPathComponent(".git").path) {
            repos.insert(rootURL.path)
        }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .nameKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return repos.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }

        let rootComponentsCount = rootURL.pathComponents.count

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isDirectory == true else {
                continue
            }

            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }

            let depth = url.standardizedFileURL.pathComponents.count - rootComponentsCount
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            let name = values.name ?? url.lastPathComponent
            if excludedDirectoryNames.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            if fileManager.fileExists(atPath: url.appendingPathComponent(".git").path) {
                repos.insert(url.standardizedFileURL.path)
                enumerator.skipDescendants()
            }
        }

        return repos.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Refreshes the git status for all projects
    func refreshStatus() {
        Task {
            for sectionIndex in sections.indices {
                for projectIndex in sections[sectionIndex].projects.indices {
                    let path = sections[sectionIndex].projects[projectIndex].path
                    async let hasChanges = checkForUncommittedChanges(at: path)
                    async let activity = getCommitActivity(at: path)
                    async let worktreeInfos = loadWorktreeInfo(for: path)
                    sections[sectionIndex].projects[projectIndex].hasUncommittedChanges = await hasChanges
                    sections[sectionIndex].projects[projectIndex].commitActivity = await activity
                    sections[sectionIndex].projects[projectIndex].worktrees = await worktreeInfos
                }
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

    /// Refreshes status for all projects without disrupting user interaction.
    /// Also checks for newly added Claude/Codex projects and reloads if needed.
    private func refreshStatusSilently() async {
        // Check if new projects have been added since last load
        let currentPaths = Set(sections.flatMap { $0.projects.map(\.path) })
        let repoFolders = SettingsService.shared.repoFolders
        let discoveryService = self.discoveryService

        let allLatestPaths = await Task.detached(priority: .utility) {
            let discoveredPaths = Set(discoveryService.discoverProjects().map(\.path))
            let repoFolderPaths = Set(repoFolders.flatMap { ProjectListViewModel.discoverGitRepositories(in: $0) })
            return discoveredPaths.union(repoFolderPaths)
        }.value

        if allLatestPaths != currentPaths {
            // Project list changed — do a full reload to pick up additions/removals
            loadProjects()
            return
        }

        // No project changes — just refresh git status
        for sectionIndex in sections.indices {
            for projectIndex in sections[sectionIndex].projects.indices {
                guard !Task.isCancelled else { break }
                let path = sections[sectionIndex].projects[projectIndex].path
                async let hasChanges = checkForUncommittedChanges(at: path)
                async let activity = getCommitActivity(at: path)
                async let lastActivity = getLastCommitDate(at: path)
                async let worktreeInfos = loadWorktreeInfo(for: path)
                sections[sectionIndex].projects[projectIndex].hasUncommittedChanges = await hasChanges
                sections[sectionIndex].projects[projectIndex].commitActivity = await activity
                sections[sectionIndex].projects[projectIndex].lastActivityDate = await lastActivity
                sections[sectionIndex].projects[projectIndex].worktrees = await worktreeInfos
            }
        }
        // Re-sort sections after refresh if in recent mode
        if sortMode == .recent {
            resortSections()
        }
    }

    deinit {
        autoRefreshTask?.cancel()
        loadProjectsTask?.cancel()
    }
}
