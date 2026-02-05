import Foundation

/// ViewModel for creating a new worktree
@MainActor
class CreateWorktreeViewModel: ObservableObject {
    @Published var branchName = ""
    @Published var isNewBranch = true
    @Published var worktreePath = ""
    @Published var existingBranches: [String] = []
    @Published var selectedExistingBranch: String?
    @Published var agentLabel: String?
    @Published var isCreating = false
    @Published var error: String?
    @Published var isLoadingBranches = false

    private let gitService = GitService()
    let repoPath: String

    init(repoPath: String) {
        self.repoPath = repoPath
    }

    /// Auto-generates worktree path based on branch name
    var autoPath: String {
        let repoURL = URL(fileURLWithPath: repoPath)
        let parentDir = repoURL.deletingLastPathComponent().path
        let repoName = repoURL.lastPathComponent
        let branch = effectiveBranch
        guard !branch.isEmpty else { return "" }
        let safeBranch = branch.replacingOccurrences(of: "/", with: "-")
        return (parentDir as NSString).appendingPathComponent("\(repoName)-\(safeBranch)")
    }

    /// The branch to use (new or existing)
    var effectiveBranch: String {
        if isNewBranch {
            return branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return selectedExistingBranch ?? ""
        }
    }

    var canCreate: Bool {
        !effectiveBranch.isEmpty && !isCreating
    }

    /// Loads local and remote branches for the existing branch picker
    func loadBranches() {
        isLoadingBranches = true
        Task {
            do {
                async let local = gitService.getLocalBranches(at: repoPath)
                async let remote = gitService.getRemoteBranches(at: repoPath)
                let (localBranches, remoteBranches) = try await (local, remote)
                // Combine and deduplicate
                var allBranches = Set(localBranches)
                for rb in remoteBranches {
                    // Strip "origin/" prefix for display
                    let name = rb.hasPrefix("origin/") ? String(rb.dropFirst("origin/".count)) : rb
                    allBranches.insert(name)
                }
                self.existingBranches = allBranches.sorted {
                    $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
                }
            } catch {
                self.existingBranches = []
            }
            self.isLoadingBranches = false
        }
    }

    /// Creates the worktree
    func createWorktree() async -> Bool {
        let branch = effectiveBranch
        guard !branch.isEmpty else {
            error = "Branch name is required"
            return false
        }

        let path = worktreePath.isEmpty ? autoPath : worktreePath
        guard !path.isEmpty else {
            error = "Worktree path could not be determined"
            return false
        }

        isCreating = true
        error = nil

        do {
            try await gitService.createWorktree(
                at: repoPath,
                newPath: path,
                branch: branch,
                createBranch: isNewBranch
            )

            // Save agent label if set
            if let label = agentLabel, !label.isEmpty {
                SettingsService.shared.setAgentLabel(label, forWorktreePath: path)
            }

            isCreating = false
            return true
        } catch {
            self.error = error.localizedDescription
            isCreating = false
            return false
        }
    }
}
