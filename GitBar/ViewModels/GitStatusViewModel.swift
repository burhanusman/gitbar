import Foundation
import SwiftUI

/// ViewModel for managing Git status display
@MainActor
class GitStatusViewModel: ObservableObject {
    @Published var gitStatus: GitStatus?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var commitMessage = ""
    @Published var isCommitting = false
    @Published var commitResult: CommitResult?

    enum CommitResult {
        case success
        case failure(Error)
    }

    private let gitService = GitService()
    private var projectPath: String?

    /// Loads the Git status for the given project path
    func loadStatus(for path: String) {
        projectPath = path
        isLoading = true
        error = nil

        Task {
            do {
                let status = try await gitService.getStatus(at: path)
                self.gitStatus = status
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
}
