import Foundation

/// Service for detecting active Claude Code sessions
struct ClaudeDetectionService: @unchecked Sendable {

    private let fileManager: FileManager

    /// Time window for considering a project as "active" (5 minutes)
    private let activityThreshold: TimeInterval = 5 * 60

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Gets the set of project paths where Claude Code is currently active
    /// - Returns: Set of project paths with active Claude sessions
    func getActiveClaudeProjects() async -> Set<String> {
        // First check if any claude process is running
        guard await isClaudeProcessRunning() else {
            return []
        }

        // Get recently modified project folders
        return getRecentlyActiveProjects()
    }

    /// Checks if any claude process is currently running
    private func isClaudeProcessRunning() async -> Bool {
        await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            task.arguments = ["-x", "claude"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()
                continuation.resume(returning: task.terminationStatus == 0)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    /// Scans the Claude projects directory for recently modified folders
    /// - Returns: Set of project paths that have been modified within the activity threshold
    private func getRecentlyActiveProjects() -> Set<String> {
        let claudeProjectsPath = getClaudeProjectsPath()

        guard fileManager.fileExists(atPath: claudeProjectsPath),
              let contents = try? fileManager.contentsOfDirectory(atPath: claudeProjectsPath) else {
            return []
        }

        let now = Date()
        var activeProjects: Set<String> = []

        for folderName in contents {
            let folderPath = "\(claudeProjectsPath)/\(folderName)"

            // Check if the folder was modified recently
            guard let attributes = try? fileManager.attributesOfItem(atPath: folderPath),
                  let modificationDate = attributes[.modificationDate] as? Date else {
                continue
            }

            // Check if modified within threshold
            let timeSinceModification = now.timeIntervalSince(modificationDate)
            guard timeSinceModification <= activityThreshold else {
                continue
            }

            // Decode the folder name to get the actual project path
            let projectPath = decodeFolderName(folderName)

            // Verify the path exists
            if fileManager.fileExists(atPath: projectPath) {
                activeProjects.insert(projectPath)
            }
        }

        return activeProjects
    }

    /// Gets the path to the Claude projects directory
    private func getClaudeProjectsPath() -> String {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser.path
        return "\(homeDirectory)/.claude/projects"
    }

    /// Decodes a Claude projects folder name to an actual file path
    /// Folder names use dashes instead of slashes: -Users-name-path becomes /Users/name/path
    private func decodeFolderName(_ folderName: String) -> String {
        guard folderName.hasPrefix("-") else {
            return folderName
        }

        var path = folderName
        path.removeFirst()
        path = "/" + path.replacingOccurrences(of: "-", with: "/")

        return path
    }
}
