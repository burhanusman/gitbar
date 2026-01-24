import Foundation
import SwiftUI
import AppKit

/// ViewModel for the Git Tree visualization
@MainActor
final class GitTreeViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var commits: [GitCommitInfo] = []
    @Published private(set) var graphNodes: [GitGraphNode] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var selectedCommitId: String?
    @Published var expandedCommitId: String?

    // MARK: - Animation State

    @Published var drawProgress: CGFloat = 0
    @Published var nodesAppeared: Set<String> = []

    // MARK: - Private

    private let gitService = GitService()
    private var repoPath: String?
    private var refreshTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var hasCommits: Bool {
        !commits.isEmpty
    }

    var currentBranch: String? {
        commits.first(where: { $0.isHead })?.branches.first
    }

    var branchColors: [String: Color] {
        var colors: [String: Color] = [:]

        for commit in commits {
            for branch in commit.branches {
                if colors[branch] == nil {
                    colors[branch] = BranchColors.color(for: branch)
                }
            }
        }

        return colors
    }

    // MARK: - Public Methods

    func loadCommits(for path: String) {
        self.repoPath = path
        isLoading = true
        error = nil

        // Reset animation state
        drawProgress = 0
        nodesAppeared.removeAll()

        Task {
            do {
                let fetchedCommits = try await gitService.getCommitLog(at: path, maxCount: 25)
                let nodes = buildGraph(from: fetchedCommits)

                await MainActor.run {
                    self.commits = fetchedCommits
                    self.graphNodes = nodes
                    self.isLoading = false
                    self.startEntryAnimation()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }

    func refresh() {
        guard let path = repoPath else { return }
        loadCommits(for: path)
    }

    func refreshQuietly() {
        guard let path = repoPath else { return }

        Task {
            do {
                let fetchedCommits = try await gitService.getCommitLog(at: path, maxCount: 25)
                let nodes = buildGraph(from: fetchedCommits)

                await MainActor.run {
                    self.commits = fetchedCommits
                    self.graphNodes = nodes
                }
            } catch {
                // Silent failure for quiet refresh
            }
        }
    }

    func toggleExpanded(for commitId: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedCommitId == commitId {
                expandedCommitId = nil
            } else {
                expandedCommitId = commitId
            }
        }
    }

    func copyCommitSha(_ sha: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sha, forType: .string)
    }

    // MARK: - Animation

    private func startEntryAnimation() {
        // Animate line drawing
        withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
            drawProgress = 1
        }

        // Stagger node appearances
        for (index, node) in graphNodes.enumerated() {
            let delay = 0.15 + Double(index) * 0.03
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    _ = self.nodesAppeared.insert(node.id)
                }
            }
        }
    }

    // MARK: - Graph Building

    private func buildGraph(from commits: [GitCommitInfo]) -> [GitGraphNode] {
        guard !commits.isEmpty else { return [] }

        var nodes: [GitGraphNode] = []
        var columnMap: [String: Int] = [:] // SHA -> column
        var activeColumns: [String?] = [nil] // Track which SHA owns each column (nil = free)

        for (rowIndex, commit) in commits.enumerated() {
            // Determine column for this commit
            let column = determineColumn(for: commit, columnMap: &columnMap, activeColumns: &activeColumns)

            // Build connections
            var connections: [GitGraphConnection] = []

            // Find parent connections
            for parentSha in commit.parentShas {
                if let parentColumn = columnMap[parentSha] {
                    // Parent already processed - this is unusual in reverse order
                    let type: GitGraphConnection.ConnectionType = parentColumn == column ? .straight : .curveIn
                    connections.append(GitGraphConnection(
                        fromColumn: column,
                        fromRow: rowIndex,
                        toColumn: parentColumn,
                        toRow: rowIndex + 1,
                        type: type,
                        branchName: commit.branches.first
                    ))
                }
            }

            // Look ahead to find children that connect to this commit
            for (childIndex, childNode) in nodes.enumerated() {
                if childNode.commit.parentShas.contains(commit.sha) {
                    let type: GitGraphConnection.ConnectionType
                    if childNode.column == column {
                        type = .straight
                    } else if childNode.commit.isMerge {
                        type = .merge
                    } else {
                        type = .curveOut
                    }

                    let connection = GitGraphConnection(
                        fromColumn: childNode.column,
                        fromRow: childIndex,
                        toColumn: column,
                        toRow: rowIndex,
                        type: type,
                        branchName: childNode.commit.branches.first ?? commit.branches.first
                    )
                    connections.append(connection)
                }
            }

            let node = GitGraphNode(
                id: commit.sha,
                commit: commit,
                column: column,
                row: rowIndex,
                connections: connections
            )
            nodes.append(node)
            columnMap[commit.sha] = column
        }

        return nodes
    }

    private func determineColumn(
        for commit: GitCommitInfo,
        columnMap: inout [String: Int],
        activeColumns: inout [String?]
    ) -> Int {
        // If this commit is a parent of an existing node, try to use that column
        for (col, ownerSha) in activeColumns.enumerated() {
            if ownerSha == commit.sha {
                // This commit was expected in this column
                // Now this column should be owned by this commit's first parent
                if let firstParent = commit.parentShas.first {
                    activeColumns[col] = firstParent
                } else {
                    activeColumns[col] = nil
                }
                return col
            }
        }

        // Find first free column
        for (col, ownerSha) in activeColumns.enumerated() {
            if ownerSha == nil {
                if let firstParent = commit.parentShas.first {
                    activeColumns[col] = firstParent
                }
                return col
            }
        }

        // Need new column
        let newCol = activeColumns.count
        if let firstParent = commit.parentShas.first {
            activeColumns.append(firstParent)
        } else {
            activeColumns.append(nil)
        }

        // Handle merge commits - second parent needs its own column
        if commit.parentShas.count > 1 {
            for parentSha in commit.parentShas.dropFirst() {
                if columnMap[parentSha] == nil {
                    // Parent not yet seen, allocate column for it
                    activeColumns.append(parentSha)
                }
            }
        }

        return newCol
    }
}

// MARK: - Branch Colors

struct BranchColors {
    static let orderedColors: [Color] = [
        Color(hex: "#3B82F6"), // Blue - main/master
        Color(hex: "#A855F7"), // Purple - feature
        Color(hex: "#22C55E"), // Green - develop
        Color(hex: "#F59E0B"), // Amber - bugfix
        Color(hex: "#06B6D4"), // Cyan - release
        Color(hex: "#EC4899"), // Pink
        Color(hex: "#8B5CF6"), // Violet
        Color(hex: "#14B8A6"), // Teal
    ]

    static func color(for branchName: String) -> Color {
        let lowercased = branchName.lowercased()

        if lowercased == "main" || lowercased == "master" {
            return Color(hex: "#3B82F6") // Accent blue
        } else if lowercased == "develop" || lowercased == "development" {
            return Color(hex: "#22C55E") // Success green
        } else if lowercased.hasPrefix("feature/") || lowercased.hasPrefix("feat/") {
            return Color(hex: "#A855F7") // Purple
        } else if lowercased.hasPrefix("bugfix/") || lowercased.hasPrefix("fix/") {
            return Color(hex: "#F59E0B") // Amber
        } else if lowercased.hasPrefix("hotfix/") {
            return Color(hex: "#EF4444") // Error red
        } else if lowercased.hasPrefix("release/") {
            return Color(hex: "#06B6D4") // Cyan
        }

        // Generate stable color from branch name hash
        let hash = abs(branchName.hashValue)
        let index = hash % orderedColors.count
        return orderedColors[index]
    }
}
