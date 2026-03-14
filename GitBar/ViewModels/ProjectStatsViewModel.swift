import Foundation
import SwiftUI

/// Token usage statistics
struct TokenUsage {
    let input: Int
    let output: Int
    let cost: Double?
}

/// File type statistics
struct FileTypeStat: Equatable {
    let `extension`: String
    let count: Int
}

/// ViewModel for project statistics display
@MainActor
class ProjectStatsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var linesAdded = 0
    @Published var linesRemoved = 0
    @Published var totalCommits = 0
    @Published var commitsThisWeek = 0
    @Published var dailyCommits: [Int] = []
    @Published var tokenUsage: TokenUsage?
    @Published var fileTypeStats: [FileTypeStat] = []
    @Published var error: Error?

    private let gitService = GitService()
    private let fileManager = FileManager.default

    /// Loads all statistics for the given project path
    func loadStats(at path: String) {
        isLoading = true
        error = nil

        Task {
            // Load git stats in parallel
            async let lineStats = loadLineStats(at: path)
            async let commitStats = loadCommitStats(at: path)
            async let fileStats = loadFileTypeStats(at: path)
            async let tokens = loadTokenUsage(for: path)

            let (lines, commits, files, tokenData) = await (lineStats, commitStats, fileStats, tokens)

            self.linesAdded = lines.added
            self.linesRemoved = lines.removed
            self.totalCommits = commits.total
            self.commitsThisWeek = commits.thisWeek
            self.dailyCommits = commits.daily
            self.fileTypeStats = files
            self.tokenUsage = tokenData
            self.isLoading = false
        }
    }

    // MARK: - Line Stats

    private func loadLineStats(at path: String) async -> (added: Int, removed: Int) {
        do {
            // Get line stats for last 30 days
            let output = try await gitService.getLineStats(at: path, days: 30)
            return parseLineStats(output)
        } catch {
            return (0, 0)
        }
    }

    private func parseLineStats(_ output: String) -> (added: Int, removed: Int) {
        var added = 0
        var removed = 0

        // Parse git shortstat output: "X files changed, Y insertions(+), Z deletions(-)"
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("insertion") || line.contains("deletion") {
                // Parse insertions
                if let insertMatch = line.range(of: #"(\d+) insertion"#, options: .regularExpression) {
                    let numStr = line[insertMatch].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    added += Int(numStr) ?? 0
                }
                // Parse deletions
                if let deleteMatch = line.range(of: #"(\d+) deletion"#, options: .regularExpression) {
                    let numStr = line[deleteMatch].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    removed += Int(numStr) ?? 0
                }
            }
        }

        return (added, removed)
    }

    // MARK: - Commit Stats

    private func loadCommitStats(at path: String) async -> (total: Int, thisWeek: Int, daily: [Int]) {
        do {
            let activityDict = try await gitService.getCommitActivity(at: path)

            // Convert [Date: Int] to ordered array (most recent first)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            var daily: [Int] = []

            for dayOffset in 0..<30 {
                if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                    let dayStart = calendar.startOfDay(for: date)
                    daily.append(activityDict[dayStart] ?? 0)
                }
            }

            // Reverse so oldest is first (for chart display left-to-right)
            daily = daily.reversed()

            let total = daily.reduce(0, +)
            let thisWeek = daily.suffix(7).reduce(0, +)
            return (total, thisWeek, daily)
        } catch {
            return (0, 0, Array(repeating: 0, count: 30))
        }
    }

    // MARK: - File Type Stats

    private func loadFileTypeStats(at path: String) async -> [FileTypeStat] {
        do {
            // Use git ls-files to get tracked files
            let output = try await gitService.listTrackedFiles(at: path)
            let files = output.components(separatedBy: "\n").filter { !$0.isEmpty }

            // Count by extension
            var extensionCounts: [String: Int] = [:]
            for file in files {
                let ext = (file as NSString).pathExtension.lowercased()
                if !ext.isEmpty {
                    extensionCounts[ext, default: 0] += 1
                }
            }

            // Sort by count descending
            return extensionCounts
                .map { FileTypeStat(extension: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }
        } catch {
            return []
        }
    }

    // MARK: - Token Usage

    private func loadTokenUsage(for path: String) async -> TokenUsage? {
        // Try to read from CodexBar cost data if available
        // CodexBar stores cost data in ~/.codexbar/costs/{project-name}.json
        let projectName = (path as NSString).lastPathComponent

        // Check multiple possible locations
        let possiblePaths = [
            NSHomeDirectory() + "/.codexbar/costs/\(projectName).json",
            NSHomeDirectory() + "/.claude/costs/\(projectName).json"
        ]

        for costPath in possiblePaths {
            if let data = fileManager.contents(atPath: costPath) {
                if let tokenData = parseTokenData(data) {
                    return tokenData
                }
            }
        }

        return nil
    }

    private func parseTokenData(_ data: Data) -> TokenUsage? {
        // Parse JSON format: { "input_tokens": X, "output_tokens": Y, "cost": Z }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let input = json["input_tokens"] as? Int ?? json["inputTokens"] as? Int ?? 0
        let output = json["output_tokens"] as? Int ?? json["outputTokens"] as? Int ?? 0
        let cost = json["cost"] as? Double ?? json["total_cost"] as? Double

        if input == 0 && output == 0 {
            return nil
        }

        return TokenUsage(input: input, output: output, cost: cost)
    }
}
