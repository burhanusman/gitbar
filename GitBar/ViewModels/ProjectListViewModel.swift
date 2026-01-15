import Foundation
import Combine

/// ViewModel for managing the project list sidebar
@MainActor
class ProjectListViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?

    private let discoveryService: ClaudeProjectDiscoveryService
    private let fileManager: FileManager

    init(discoveryService: ClaudeProjectDiscoveryService = ClaudeProjectDiscoveryService(),
         fileManager: FileManager = .default) {
        self.discoveryService = discoveryService
        self.fileManager = fileManager
    }

    /// Loads projects and checks their git status
    func loadProjects() {
        let discoveredProjects = discoveryService.discoverProjects()
        projects = discoveredProjects.map { claudeProject in
            let hasChanges = checkForUncommittedChanges(at: claudeProject.path)
            return Project(from: claudeProject, hasUncommittedChanges: hasChanges)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Selects a project
    func selectProject(_ project: Project) {
        selectedProject = project
    }

    /// Checks if a Git repository has uncommitted changes
    private func checkForUncommittedChanges(at path: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path, "status", "--porcelain"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            // If there's any output, there are uncommitted changes
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }

    /// Refreshes the git status for all projects
    func refreshStatus() {
        for index in projects.indices {
            projects[index].hasUncommittedChanges = checkForUncommittedChanges(at: projects[index].path)
        }
    }
}
