import Foundation
import SwiftUI

/// ViewModel for managing Git status display
@MainActor
class GitStatusViewModel: ObservableObject {
    @Published var gitStatus: GitStatus?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var branches: [String] = []
    @Published var worktrees: [GitWorktree] = []
    @Published var isSwitchingBranch = false
    @Published var commitMessage = ""
    @Published var isCommitting = false
    @Published var commitResult: CommitResult?
    @Published var isPushing = false
    @Published var isPulling = false
    @Published var syncResult: SyncResult?
    @Published var isAutoRefreshEnabled = true

    enum CommitResult {
        case success
        case failure(Error)
    }

    enum SyncResult {
        case pushSuccess
        case pullSuccess
        case failure(Error)
    }

    private let gitService = GitService()
    private var projectPath: String?
    private var autoRefreshTask: Task<Void, Never>?

    /// Refresh interval for active project status (30 seconds)
    private let autoRefreshInterval: TimeInterval = 30

    var activePath: String? {
        projectPath
    }

    /// Loads the Git status for the given project path
    func loadStatus(for path: String) {
        projectPath = path
        isLoading = true
        error = nil

        Task {
            do {
                async let status = gitService.getStatus(at: path)
                async let branches = gitService.getLocalBranches(at: path)
                async let worktrees = gitService.getWorktrees(at: path)

                let (resolvedStatus, resolvedBranches, resolvedWorktrees) = try await (status, branches, worktrees)
                self.gitStatus = resolvedStatus
                self.branches = resolvedBranches.sorted {
                    $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
                }
                self.worktrees = resolvedWorktrees.sorted {
                    $0.path.localizedStandardCompare($1.path) == .orderedAscending
                }
                self.isLoading = false
            } catch {
                self.error = error
                self.isLoading = false
            }
        }
    }

    /// Refreshes the Git status for the current project
    func refresh() {
        guard let path = projectPath else { return }
        loadStatus(for: path)
    }

    func checkoutBranch(_ branch: String) {
        guard let path = projectPath else { return }
        guard branch != gitStatus?.currentBranch else { return }
        guard !isSwitchingBranch else { return }

        isSwitchingBranch = true
        error = nil

        Task {
            do {
                try await gitService.checkoutBranch(branch, at: path)

                async let status = gitService.getStatus(at: path)
                async let branches = gitService.getLocalBranches(at: path)
                async let worktrees = gitService.getWorktrees(at: path)

                let (resolvedStatus, resolvedBranches, resolvedWorktrees) = try await (status, branches, worktrees)
                self.gitStatus = resolvedStatus
                self.branches = resolvedBranches.sorted {
                    $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
                }
                self.worktrees = resolvedWorktrees.sorted {
                    $0.path.localizedStandardCompare($1.path) == .orderedAscending
                }
            } catch {
                self.error = error
            }

            self.isSwitchingBranch = false
        }
    }

    func switchToWorktree(at path: String) {
        loadStatus(for: path)
    }

    /// Returns staged files
    var stagedFiles: [GitFileChange] {
        gitStatus?.stagedChanges ?? []
    }

    /// Returns modified (unstaged) files
    var modifiedFiles: [GitFileChange] {
        gitStatus?.unstagedChanges.filter { $0.status != .untracked } ?? []
    }

    /// Returns untracked files
    var untrackedFiles: [GitFileChange] {
        gitStatus?.unstagedChanges.filter { $0.status == .untracked } ?? []
    }

    /// Formats the ahead/behind indicator string
    var aheadBehindText: String? {
        guard let ab = gitStatus?.aheadBehind, ab.hasChanges else { return nil }

        var parts: [String] = []
        if ab.ahead > 0 {
            parts.append("↑\(ab.ahead)")
        }
        if ab.behind > 0 {
            parts.append("↓\(ab.behind)")
        }
        return parts.joined(separator: " ")
    }

    /// Whether there are any changes to display
    var hasChanges: Bool {
        gitStatus?.hasUncommittedChanges ?? false
    }

    /// Whether the commit button should be enabled
    var canCommit: Bool {
        !stagedFiles.isEmpty && !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCommitting
    }

    /// Whether the push button should be enabled (ahead of remote)
    var canPush: Bool {
        guard let aheadBehind = gitStatus?.aheadBehind else { return false }
        return aheadBehind.ahead > 0 && !isPushing && !isPulling
    }

    /// Whether the pull button should be enabled (behind remote)
    var canPull: Bool {
        guard let aheadBehind = gitStatus?.aheadBehind else { return false }
        return aheadBehind.behind > 0 && !isPushing && !isPulling
    }

    /// Commits staged changes with the current commit message
    func commit() {
        guard let path = projectPath else { return }
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !stagedFiles.isEmpty else { return }

        isCommitting = true
        commitResult = nil

        Task {
            do {
                try await gitService.commit(message: message, at: path)
                self.commitMessage = ""
                self.commitResult = .success
                refresh()
            } catch {
                self.commitResult = .failure(error)
            }
            self.isCommitting = false
        }
    }

    /// Clears the commit result feedback
    func clearCommitResult() {
        commitResult = nil
    }

    /// Clears the sync result feedback
    func clearSyncResult() {
        syncResult = nil
    }

    /// Pushes commits to remote
    func push() {
        guard let path = projectPath else { return }
        guard canPush else { return }

        isPushing = true
        syncResult = nil

        Task {
            do {
                try await gitService.push(at: path)
                self.syncResult = .pushSuccess
                refresh()
            } catch {
                self.syncResult = .failure(error)
            }
            self.isPushing = false
        }
    }

    /// Pulls changes from remote
    func pull() {
        guard let path = projectPath else { return }
        guard canPull else { return }

        isPulling = true
        syncResult = nil

        Task {
            do {
                try await gitService.pull(at: path)
                self.syncResult = .pullSuccess
                refresh()
            } catch {
                self.syncResult = .failure(error)
            }
            self.isPulling = false
        }
    }

    /// Stages a file and refreshes the status
    func stageFile(_ filePath: String) {
        guard let path = projectPath else { return }
        Task {
            do {
                try await gitService.stageFile(filePath, at: path)
                refresh()
            } catch {
                self.error = error
            }
        }
    }

    /// Unstages a file and refreshes the status
    func unstageFile(_ filePath: String) {
        guard let path = projectPath else { return }
        Task {
            do {
                try await gitService.unstageFile(filePath, at: path)
                refresh()
            } catch {
                self.error = error
            }
        }
    }

    // MARK: - Auto-Refresh

    /// Starts the auto-refresh timer for the active project
    func startAutoRefresh() {
        stopAutoRefresh()
        guard isAutoRefreshEnabled else { return }

        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(autoRefreshInterval * 1_000_000_000))
                guard !Task.isCancelled, isAutoRefreshEnabled else { break }
                await refreshSilently()
            }
        }
    }

    /// Stops the auto-refresh timer
    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    /// Refreshes status without showing loading indicator (for auto-refresh)
    private func refreshSilently() async {
        guard let path = projectPath else { return }
        do {
            let status = try await gitService.getStatus(at: path)
            self.gitStatus = status
        } catch {
            // Silently ignore errors during auto-refresh to avoid disrupting the user
        }
    }

    deinit {
        autoRefreshTask?.cancel()
    }
}
