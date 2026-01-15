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

    /// Gets the list of file changes (staged and unstaged)
    func getFileChanges(at path: String) async throws -> [GitFileChange] {
        try validateGitRepository(at: path)

        let output = try await runGitCommand(["status", "--porcelain"], at: path)
        return parseStatusOutput(output)
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

    /// Checks if a path is a valid Git repository
    func isGitRepository(at path: String) -> Bool {
        let gitDir = (path as NSString).appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: gitDir, isDirectory: &isDirectory) && isDirectory.boolValue
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
}
