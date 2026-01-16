import Foundation

/// Represents the source of a discovered project
enum ProjectSource: String, Codable, Equatable {
    case claude = "Claude"
    case codex = "Codex"
    case folder = "Folder"
}

/// Represents a Git project displayed in the sidebar
struct Project: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let source: ProjectSource
    var hasUncommittedChanges: Bool

    init(name: String, path: String, source: ProjectSource = .folder, hasUncommittedChanges: Bool = false) {
        self.id = path
        self.name = name
        self.path = path
        self.source = source
        self.hasUncommittedChanges = hasUncommittedChanges
    }

    /// Creates a Project from a ClaudeProject (works for both Claude and Codex)
    init(from claudeProject: ClaudeProjectDiscoveryService.ClaudeProject, hasUncommittedChanges: Bool = false) {
        self.id = claudeProject.path
        self.name = claudeProject.name
        self.path = claudeProject.path
        self.source = claudeProject.source
        self.hasUncommittedChanges = hasUncommittedChanges
    }
}
