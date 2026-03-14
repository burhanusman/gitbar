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

    /// Scans the Claude projects directory for recently active sessions
    /// - Returns: Set of project paths that have session files modified within the activity threshold
    private func getRecentlyActiveProjects() -> Set<String> {
        let claudeProjectsPath = getClaudeProjectsPath()

        guard fileManager.fileExists(atPath: claudeProjectsPath),
              let contents = try? fileManager.contentsOfDirectory(atPath: claudeProjectsPath) else {
            return []
        }

        let now = Date()
        var activeProjects: Set<String> = []

        for folderName in contents {
            // Skip hidden files/folders
            guard !folderName.hasPrefix(".") else { continue }

            let folderPath = "\(claudeProjectsPath)/\(folderName)"

            // Check if any session file (.jsonl) inside was modified recently
            guard hasRecentlyModifiedSessionFile(in: folderPath, now: now) else {
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

    /// Checks if a project folder contains any recently modified session files
    private func hasRecentlyModifiedSessionFile(in folderPath: String, now: Date) -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: folderPath) else {
            return false
        }

        for fileName in contents {
            // Session files are .jsonl files
            guard fileName.hasSuffix(".jsonl") else { continue }

            let filePath = "\(folderPath)/\(fileName)"
            guard let attributes = try? fileManager.attributesOfItem(atPath: filePath),
                  let modificationDate = attributes[.modificationDate] as? Date else {
                continue
            }

            let timeSinceModification = now.timeIntervalSince(modificationDate)
            if timeSinceModification <= activityThreshold {
                return true
            }
        }

        return false
    }

    /// Gets the path to the Claude projects directory
    private func getClaudeProjectsPath() -> String {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser.path
        return "\(homeDirectory)/.claude/projects"
    }

    /// Decodes a Claude projects folder name to an actual file path
    /// Encoding scheme:
    /// - `/` becomes `-`
    /// - `-` becomes `--` (escaped)
    /// Example: `-Users-burhan-my--project` → `/Users/burhan/my-project`
    private func decodeFolderName(_ folderName: String) -> String {
        guard folderName.hasPrefix("-") else {
            return folderName
        }

        // Use a placeholder for escaped dashes, then convert
        let placeholder = "\u{0000}"
        var path = folderName
        path.removeFirst() // Remove leading dash

        // First, replace escaped dashes (--) with placeholder
        path = path.replacingOccurrences(of: "--", with: placeholder)
        // Then replace single dashes with slashes
        path = path.replacingOccurrences(of: "-", with: "/")
        // Finally, restore escaped dashes
        path = path.replacingOccurrences(of: placeholder, with: "-")

        return "/" + path
    }
}
