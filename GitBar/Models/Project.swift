import Foundation

/// Represents a Git project displayed in the sidebar
struct Project: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    var hasUncommittedChanges: Bool

    init(name: String, path: String, hasUncommittedChanges: Bool = false) {
        self.id = path
        self.name = name
        self.path = path
        self.hasUncommittedChanges = hasUncommittedChanges
    }

    /// Creates a Project from a ClaudeProject
    init(from claudeProject: ClaudeProjectDiscoveryService.ClaudeProject, hasUncommittedChanges: Bool = false) {
        self.id = claudeProject.path
        self.name = claudeProject.name
        self.path = claudeProject.path
        self.hasUncommittedChanges = hasUncommittedChanges
    }
}
