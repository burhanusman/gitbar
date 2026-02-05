import Foundation

/// Represents the source of a discovered project
enum ProjectSource: String, Codable, Equatable {
    case claude = "Claude"
    case codex = "Codex"
    case folder = "Folder"
}

/// Represents daily commit activity for a project
struct CommitActivity: Equatable {
    let dailyCounts: [Int]  // Array of commit counts, index 0 = today, index 1 = yesterday, etc.

    /// Returns the last N days of activity
    func last(_ days: Int) -> [Int] {
        Array(dailyCounts.prefix(days))
    }

    /// Maximum commits in a single day (for normalization)
    var maxCount: Int {
        dailyCounts.max() ?? 0
    }

    /// Total commits in the period
    var totalCommits: Int {
        dailyCounts.reduce(0, +)
    }

    static let empty = CommitActivity(dailyCounts: Array(repeating: 0, count: 30))
}

/// Represents a worktree associated with a project
struct WorktreeInfo: Identifiable, Equatable {
    let id: String
    let path: String
    let branch: String?
    let head: String?
    let isDetached: Bool
    let isMain: Bool
    var hasUncommittedChanges: Bool
    var agentLabel: String?

    init(path: String, branch: String?, head: String?, isDetached: Bool, isMain: Bool, hasUncommittedChanges: Bool = false, agentLabel: String? = nil) {
        self.id = path
        self.path = path
        self.branch = branch
        self.head = head
        self.isDetached = isDetached
        self.isMain = isMain
        self.hasUncommittedChanges = hasUncommittedChanges
        self.agentLabel = agentLabel
    }
}

/// Represents a Git project displayed in the sidebar
struct Project: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let source: ProjectSource
    var hasUncommittedChanges: Bool
    var commitActivity: CommitActivity
    var lastActivityDate: Date?
    var worktrees: [WorktreeInfo]
    var activeWorktreePath: String?

    var hasWorktrees: Bool {
        worktrees.count > 1
    }

    init(name: String, path: String, source: ProjectSource = .folder, hasUncommittedChanges: Bool = false, commitActivity: CommitActivity = .empty, lastActivityDate: Date? = nil, worktrees: [WorktreeInfo] = [], activeWorktreePath: String? = nil) {
        self.id = path
        self.name = name
        self.path = path
        self.source = source
        self.hasUncommittedChanges = hasUncommittedChanges
        self.commitActivity = commitActivity
        self.lastActivityDate = lastActivityDate
        self.worktrees = worktrees
        self.activeWorktreePath = activeWorktreePath
    }

    /// Creates a Project from a ClaudeProject (works for both Claude and Codex)
    init(from claudeProject: ClaudeProjectDiscoveryService.ClaudeProject, hasUncommittedChanges: Bool = false, commitActivity: CommitActivity = .empty, lastActivityDate: Date? = nil) {
        self.id = claudeProject.path
        self.name = claudeProject.name
        self.path = claudeProject.path
        self.source = claudeProject.source
        self.hasUncommittedChanges = hasUncommittedChanges
        self.commitActivity = commitActivity
        self.lastActivityDate = lastActivityDate
        self.worktrees = []
        self.activeWorktreePath = nil
    }
}
