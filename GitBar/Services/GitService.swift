import Foundation

/// Errors that can occur during Git operations
enum GitError: Error, LocalizedError {
    case notAGitRepository
    case commandFailed(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .notAGitRepository:
            return "Not a Git repository"
        case .commandFailed(let message):
            return "Git command failed: \(message)"
        case .invalidOutput:
            return "Invalid Git output"
        }
    }
}

/// Represents line change statistics for a file
struct GitLineStats: Equatable {
    let added: Int
    let removed: Int

    var description: String {
        var parts: [String] = []
        if added > 0 { parts.append("+\(added)") }
        if removed > 0 { parts.append("-\(removed)") }
        return parts.joined(separator: " ")
    }

    var isEmpty: Bool {
        added == 0 && removed == 0
    }
}

/// Represents a file change from git status
struct GitFileChange: Equatable {
    enum Status: String {
        case modified = "M"
        case added = "A"
        case deleted = "D"
        case renamed = "R"
        case copied = "C"
        case untracked = "?"
        case ignored = "!"
        case unmerged = "U"
        case typeChanged = "T"

        init?(indexStatus: Character, workTreeStatus: Character) {
            // Prioritize working tree status, then index status
            if workTreeStatus == "?" {
                self = .untracked
            } else if workTreeStatus == "!" {
                self = .ignored
            } else if workTreeStatus == "M" || indexStatus == "M" {
                self = .modified
            } else if workTreeStatus == "A" || indexStatus == "A" {
                self = .added
            } else if workTreeStatus == "D" || indexStatus == "D" {
                self = .deleted
            } else if indexStatus == "R" {
                self = .renamed
            } else if indexStatus == "C" {
                self = .copied
            } else if indexStatus == "U" || workTreeStatus == "U" {
                self = .unmerged
            } else if indexStatus == "T" || workTreeStatus == "T" {
                self = .typeChanged
            } else if indexStatus != " " || workTreeStatus != " " {
                self = .modified
            } else {
                return nil
            }
        }
    }

    let path: String
    let status: Status
    let isStaged: Bool
    var lineStats: GitLineStats?
}

/// Represents ahead/behind status relative to upstream
struct GitAheadBehind: Equatable {
    let ahead: Int
    let behind: Int

    var hasChanges: Bool {
        ahead > 0 || behind > 0
    }
}

/// Represents the overall status of a Git repository
struct GitStatus: Equatable {
    let currentBranch: String?
    let changes: [GitFileChange]
    let aheadBehind: GitAheadBehind?

    var hasUncommittedChanges: Bool {
        !changes.isEmpty
    }

    var stagedChanges: [GitFileChange] {
        changes.filter { $0.isStaged }
    }

    var unstagedChanges: [GitFileChange] {
        changes.filter { !$0.isStaged }
    }
}

/// Represents a commit with full information for tree visualization
struct GitCommitInfo: Identifiable, Equatable {
    let id: String // Same as sha
    let sha: String
    let shortSha: String
    let message: String
    let authorName: String
    let authorEmail: String
    let date: Date
    let parentShas: [String]
    let branches: [String]
    let isHead: Bool
    let isMerge: Bool

    init(sha: String, shortSha: String, message: String, authorName: String, authorEmail: String, date: Date, parentShas: [String], branches: [String], isHead: Bool, isMerge: Bool) {
        self.id = sha
        self.sha = sha
        self.shortSha = shortSha
        self.message = message
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.date = date
        self.parentShas = parentShas
        self.branches = branches
        self.isHead = isHead
        self.isMerge = isMerge
    }

    /// Returns relative time string like "3m ago", "2h ago", "1d ago"
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Represents a node in the git graph with position information
struct GitGraphNode: Identifiable, Equatable {
    let id: String
    let commit: GitCommitInfo
    let column: Int
    let row: Int
    let connections: [GitGraphConnection]
}

/// Represents a connection/line in the git graph
struct GitGraphConnection: Equatable, Hashable {
    enum ConnectionType: Equatable, Hashable {
        case straight      // Vertical line in same column
        case curveOut      // Branch diverging outward
        case curveIn       // Branch merging inward
        case merge         // Merge commit connection
    }

    let fromColumn: Int
    let fromRow: Int
    let toColumn: Int
    let toRow: Int
    let type: ConnectionType
    let branchName: String?
}

/// Represents a Git worktree entry
struct GitWorktree: Identifiable, Equatable {
    let id: String
    let path: String
    let branch: String?
    let head: String?
    let isDetached: Bool

    init(path: String, branch: String?, head: String?, isDetached: Bool) {
        self.id = path
        self.path = path
        self.branch = branch
        self.head = head
        self.isDetached = isDetached
    }
}

/// Service for executing Git commands and parsing their output
actor GitService {
    private let gitPath: String
    private let fileManager: FileManager

    init(gitPath: String = "/usr/bin/git", fileManager: FileManager = .default) {
        self.gitPath = gitPath
        self.fileManager = fileManager
    }

    // MARK: - Public Methods

    /// Gets the full status of a Git repository
    func getStatus(at path: String) async throws -> GitStatus {
        try validateGitRepository(at: path)

        async let branch = getCurrentBranch(at: path)
        async let changes = getFileChanges(at: path)
        async let aheadBehind = getAheadBehind(at: path)

        return try await GitStatus(
            currentBranch: branch,
            changes: changes,
            aheadBehind: aheadBehind
        )
    }

    /// Gets the current branch name
    func getCurrentBranch(at path: String) async throws -> String? {
        try validateGitRepository(at: path)

        let output = try await runGitCommand(["branch", "--show-current"], at: path)
        let branch = output.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty output means detached HEAD state
        return branch.isEmpty ? nil : branch
    }

    /// Gets the list of file changes (staged and unstaged) with line stats
    func getFileChanges(at path: String) async throws -> [GitFileChange] {
        try validateGitRepository(at: path)

        async let statusOutput = runGitCommand(["status", "--porcelain"], at: path)
        async let stagedStats = runGitCommand(["diff", "--cached", "--numstat"], at: path)
        async let unstagedStats = runGitCommand(["diff", "--numstat"], at: path)

        let (status, staged, unstaged) = try await (statusOutput, stagedStats, unstagedStats)

        var changes = parseStatusOutput(status)

        // Parse line stats
        let stagedLineStats = parseNumstatOutput(staged)
        let unstagedLineStats = parseNumstatOutput(unstaged)

        // Merge line stats into changes
        for i in changes.indices {
            let filePath = changes[i].path
            if changes[i].isStaged {
                changes[i].lineStats = stagedLineStats[filePath]
            } else {
                changes[i].lineStats = unstagedLineStats[filePath]
            }
        }

        return changes
    }

    /// Gets line stats for a specific file
    func getLineStats(for filePath: String, staged: Bool, at repoPath: String) async throws -> GitLineStats? {
        try validateGitRepository(at: repoPath)

        let args = staged
            ? ["diff", "--cached", "--numstat", "--", filePath]
            : ["diff", "--numstat", "--", filePath]

        let output = try await runGitCommand(args, at: repoPath)
        let stats = parseNumstatOutput(output)
        return stats[filePath]
    }

    /// Checks if there are any uncommitted changes
    func hasUncommittedChanges(at path: String) async throws -> Bool {
        let changes = try await getFileChanges(at: path)
        return !changes.isEmpty
    }

    /// Gets the ahead/behind count relative to upstream
    func getAheadBehind(at path: String) async throws -> GitAheadBehind? {
        try validateGitRepository(at: path)

        // First check if we have an upstream configured
        let upstreamResult = try? await runGitCommand(
            ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            at: path
        )

        guard upstreamResult != nil,
              !upstreamResult!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // No upstream configured
            return nil
        }

        let output = try await runGitCommand(
            ["rev-list", "--left-right", "--count", "@{upstream}...HEAD"],
            at: path
        )

        return parseAheadBehindOutput(output)
    }

    /// Lists local branch names
    func getLocalBranches(at path: String) async throws -> [String] {
        try validateGitRepository(at: path)

        let output = try await runGitCommand(
            ["for-each-ref", "--format=%(refname:short)", "refs/heads"],
            at: path
        )

        return output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Switches to a local branch
    func checkoutBranch(_ branch: String, at path: String) async throws {
        try validateGitRepository(at: path)
        _ = try await runGitCommand(["checkout", branch], at: path)
    }

    /// Creates a new branch and checks it out
    func createAndCheckoutBranch(_ branch: String, at path: String) async throws {
        try validateGitRepository(at: path)
        _ = try await runGitCommand(["checkout", "-b", branch], at: path)
    }

    /// Lists worktrees for a repository
    func getWorktrees(at path: String) async throws -> [GitWorktree] {
        try validateGitRepository(at: path)
        let output = try await runGitCommand(["worktree", "list", "--porcelain"], at: path)
        return parseWorktreeListOutput(output)
    }

    /// Checks if a path is a valid Git repository
    func isGitRepository(at path: String) -> Bool {
        let gitDir = (path as NSString).appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: gitDir, isDirectory: &isDirectory)
    }

    /// Stages a file using git add
    func stageFile(_ filePath: String, at repoPath: String) async throws {
        try validateGitRepository(at: repoPath)
        _ = try await runGitCommand(["add", filePath], at: repoPath)
    }

    /// Unstages a file using git restore --staged
    func unstageFile(_ filePath: String, at repoPath: String) async throws {
        try validateGitRepository(at: repoPath)
        _ = try await runGitCommand(["restore", "--staged", filePath], at: repoPath)
    }

    /// Commits staged changes with the given message
    func commit(message: String, at repoPath: String) async throws {
        try validateGitRepository(at: repoPath)
        _ = try await runGitCommand(["commit", "-m", message], at: repoPath)
    }

    /// Pushes commits to the remote repository
    func push(at repoPath: String) async throws {
        try validateGitRepository(at: repoPath)
        _ = try await runGitCommand(["push"], at: repoPath)
    }

    /// Pulls changes from the remote repository
    func pull(at repoPath: String) async throws {
        try validateGitRepository(at: repoPath)
        _ = try await runGitCommand(["pull"], at: repoPath)
    }

    /// Restores a file (discards changes) using git restore
    func restoreFile(_ filePath: String, at repoPath: String) async throws {
        try validateGitRepository(at: repoPath)
        _ = try await runGitCommand(["restore", filePath], at: repoPath)
    }

    /// Stages all changes using git add .
    func stageAllFiles(at repoPath: String) async throws {
        try validateGitRepository(at: repoPath)
        _ = try await runGitCommand(["add", "."], at: repoPath)
    }

    /// Unstages all files using git restore --staged .
    func unstageAllFiles(at repoPath: String) async throws {
        try validateGitRepository(at: repoPath)
        _ = try await runGitCommand(["restore", "--staged", "."], at: repoPath)
    }

    /// Discards all changes using git restore .
    func restoreAllFiles(at repoPath: String) async throws {
        try validateGitRepository(at: repoPath)
        // Note: 'git restore .' only discards modified tracked files.
        // It does not clean untracked files. For that 'git clean -fd' would be needed,
        // but let's stick to safe restore for now or just restore tracked.
        _ = try await runGitCommand(["restore", "."], at: repoPath)
    }

    /// Gets the date of the last commit in the repository
    func getLastCommitDate(at path: String) async throws -> Date? {
        try validateGitRepository(at: path)

        let output = try await runGitCommand([
            "log", "-1", "--format=%ct"
        ], at: path)

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let timestamp = TimeInterval(trimmed) else {
            return nil
        }

        return Date(timeIntervalSince1970: timestamp)
    }

    /// Gets the commit log with graph information for visualization
    func getCommitLog(at path: String, maxCount: Int = 20) async throws -> [GitCommitInfo] {
        try validateGitRepository(at: path)

        // Get commit log with parent info and branch refs
        // Format: hash|short_hash|subject|author_name|author_email|timestamp|parent_hashes|refs
        let output = try await runGitCommand([
            "log",
            "--all",
            "-n", "\(maxCount)",
            "--format=%H|%h|%s|%an|%ae|%ct|%P|%D",
            "--date-order"
        ], at: path)

        // Get current HEAD
        let headOutput = try await runGitCommand(["rev-parse", "HEAD"], at: path)
        let headSha = headOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        return parseCommitLogOutput(output, headSha: headSha)
    }

    /// Gets all branches with their tip commits
    func getBranchTips(at path: String) async throws -> [String: String] {
        try validateGitRepository(at: path)

        let output = try await runGitCommand([
            "for-each-ref",
            "--format=%(refname:short)|%(objectname)",
            "refs/heads"
        ], at: path)

        var tips: [String: String] = [:]
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: "|")
            guard parts.count == 2 else { continue }
            tips[parts[0]] = parts[1]
        }
        return tips
    }

    /// Gets commit activity for the last N days (returns commit count per day)
    func getCommitActivity(at path: String, days: Int = 30) async throws -> [Date: Int] {
        try validateGitRepository(at: path)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get commits from the last N days
        let sinceDate = calendar.date(byAdding: .day, value: -days, to: today)!
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        let output = try await runGitCommand([
            "log",
            "--since=\(dateFormatter.string(from: sinceDate))",
            "--format=%cd",
            "--date=short"
        ], at: path)

        // Parse output and count commits per day
        var activity: [Date: Int] = [:]

        // Initialize all days with 0
        for dayOffset in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                activity[calendar.startOfDay(for: date)] = 0
            }
        }

        // Count commits per day
        let lines = output.components(separatedBy: .newlines)
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let date = inputFormatter.date(from: trimmed) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            activity[dayStart, default: 0] += 1
        }

        return activity
    }

    // MARK: - Private Methods

    /// Validates that the path is a Git repository, throws if not
    private func validateGitRepository(at path: String) throws {
        guard isGitRepository(at: path) else {
            throw GitError.notAGitRepository
        }
    }

    /// Runs a Git command and returns the output
    private func runGitCommand(_ arguments: [String], at path: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: gitPath)
            process.arguments = ["-C", path] + arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: GitError.commandFailed(error.localizedDescription))
                return
            }

            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                continuation.resume(throwing: GitError.commandFailed(errorMessage.trimmingCharacters(in: .whitespacesAndNewlines)))
                return
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            continuation.resume(returning: output)
        }
    }

    /// Parses git status --porcelain output into file changes
    private func parseStatusOutput(_ output: String) -> [GitFileChange] {
        var changes: [GitFileChange] = []

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            guard line.count >= 3 else { continue }

            let indexStatus = line[line.startIndex]
            let workTreeStatus = line[line.index(line.startIndex, offsetBy: 1)]
            let filePath = String(line.dropFirst(3))

            // Handle renamed files (format: "R  old -> new")
            let actualPath: String
            if indexStatus == "R" || indexStatus == "C", let arrowRange = filePath.range(of: " -> ") {
                actualPath = String(filePath[arrowRange.upperBound...])
            } else {
                actualPath = filePath
            }

            // Determine if the change is staged (index has a status other than space or ?)
            let isStaged = indexStatus != " " && indexStatus != "?"

            if let status = GitFileChange.Status(indexStatus: indexStatus, workTreeStatus: workTreeStatus) {
                changes.append(GitFileChange(path: actualPath, status: status, isStaged: isStaged))
            }
        }

        return changes
    }

    /// Parses git rev-list --left-right --count output
    private func parseAheadBehindOutput(_ output: String) -> GitAheadBehind? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        guard parts.count == 2,
              let behind = Int(parts[0]),
              let ahead = Int(parts[1]) else {
            return nil
        }

        return GitAheadBehind(ahead: ahead, behind: behind)
    }

    /// Parses `git worktree list --porcelain` output
    private func parseWorktreeListOutput(_ output: String) -> [GitWorktree] {
        var worktrees: [GitWorktree] = []

        var currentPath: String?
        var currentBranch: String?
        var currentHead: String?
        var isDetached = false

        func flush() {
            guard let path = currentPath else { return }
            worktrees.append(
                GitWorktree(
                    path: path,
                    branch: currentBranch,
                    head: currentHead,
                    isDetached: isDetached
                )
            )
            currentPath = nil
            currentBranch = nil
            currentHead = nil
            isDetached = false
        }

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                flush()
                continue
            }

            if trimmed.hasPrefix("worktree ") {
                flush()
                currentPath = String(trimmed.dropFirst("worktree ".count))
                continue
            }

            if trimmed.hasPrefix("HEAD ") {
                currentHead = String(trimmed.dropFirst("HEAD ".count))
                continue
            }

            if trimmed == "detached" {
                isDetached = true
                currentBranch = nil
                continue
            }

            if trimmed.hasPrefix("branch ") {
                let ref = String(trimmed.dropFirst("branch ".count))
                if ref.hasPrefix("refs/heads/") {
                    currentBranch = String(ref.dropFirst("refs/heads/".count))
                } else {
                    currentBranch = ref
                }
                continue
            }
        }

        flush()
        return worktrees
    }

    /// Parses git log output into commit info objects
    private func parseCommitLogOutput(_ output: String, headSha: String) -> [GitCommitInfo] {
        var commits: [GitCommitInfo] = []

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Format: hash|short_hash|subject|author_name|author_email|timestamp|parent_hashes|refs
            let parts = trimmed.components(separatedBy: "|")
            guard parts.count >= 6 else { continue }

            let sha = parts[0]
            let shortSha = parts[1]
            let message = parts[2]
            let authorName = parts[3]
            let authorEmail = parts[4]
            let timestamp = TimeInterval(parts[5]) ?? 0
            let parentShas = parts.count > 6 ? parts[6].components(separatedBy: " ").filter { !$0.isEmpty } : []
            let refsString = parts.count > 7 ? parts[7] : ""

            // Parse refs (branches and tags)
            let branches = parseRefs(refsString)

            let commit = GitCommitInfo(
                sha: sha,
                shortSha: shortSha,
                message: message,
                authorName: authorName,
                authorEmail: authorEmail,
                date: Date(timeIntervalSince1970: timestamp),
                parentShas: parentShas,
                branches: branches,
                isHead: sha == headSha,
                isMerge: parentShas.count > 1
            )
            commits.append(commit)
        }

        return commits
    }

    /// Parses refs string from git log into branch names
    private func parseRefs(_ refsString: String) -> [String] {
        guard !refsString.isEmpty else { return [] }

        var branches: [String] = []
        let refs = refsString.components(separatedBy: ", ")

        for ref in refs {
            let trimmed = ref.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Skip HEAD pointer
            if trimmed == "HEAD" { continue }
            if trimmed.hasPrefix("HEAD -> ") {
                let branchName = String(trimmed.dropFirst("HEAD -> ".count))
                branches.append(branchName)
                continue
            }

            // Skip tags for now (could add later)
            if trimmed.hasPrefix("tag: ") { continue }

            // Remote tracking refs
            if trimmed.hasPrefix("origin/") {
                // Skip remote refs, we only want local branches
                continue
            }

            // Local branch
            branches.append(trimmed)
        }

        return branches
    }

    /// Parses `git diff --numstat` output into a dictionary of file path -> line stats
    private func parseNumstatOutput(_ output: String) -> [String: GitLineStats] {
        var stats: [String: GitLineStats] = [:]

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Format: added<tab>removed<tab>filename
            // Binary files show "-" for added/removed
            let parts = trimmed.components(separatedBy: "\t")
            guard parts.count >= 3 else { continue }

            let addedStr = parts[0]
            let removedStr = parts[1]
            let filePath = parts[2...].joined(separator: "\t") // Handle paths with tabs

            // Skip binary files (shown as "-")
            guard addedStr != "-" && removedStr != "-" else { continue }

            if let added = Int(addedStr), let removed = Int(removedStr) {
                stats[filePath] = GitLineStats(added: added, removed: removed)
            }
        }

        return stats
    }
}
