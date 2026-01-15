import Foundation

/// Service for discovering Claude Code projects by scanning ~/.claude/projects/
struct ClaudeProjectDiscoveryService {

    /// Represents a discovered Claude Code project
    struct ClaudeProject {
        let path: String
        let name: String
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Discovers all valid Claude Code projects
    /// - Returns: Array of valid Git project paths
    func discoverProjects() -> [ClaudeProject] {
        let claudeProjectsPath = getClaudeProjectsPath()

        guard fileManager.fileExists(atPath: claudeProjectsPath) else {
            return []
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: claudeProjectsPath) else {
            return []
        }

        return contents.compactMap { folderName -> ClaudeProject? in
            let decodedPath = decodeFolderName(folderName)

            guard isValidGitRepository(at: decodedPath) else {
                return nil
            }

            let projectName = URL(fileURLWithPath: decodedPath).lastPathComponent
            return ClaudeProject(path: decodedPath, name: projectName)
        }
    }

    /// Gets the path to the Claude projects directory
    /// - Returns: Path to ~/.claude/projects/
    func getClaudeProjectsPath() -> String {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser.path
        return "\(homeDirectory)/.claude/projects"
    }

    /// Decodes a Claude projects folder name to an actual file path
    /// Folder names use dashes instead of slashes: -Users-name-path becomes /Users/name/path
    /// - Parameter folderName: The encoded folder name
    /// - Returns: The decoded file system path
    func decodeFolderName(_ folderName: String) -> String {
        guard folderName.hasPrefix("-") else {
            return folderName
        }

        // Replace leading - with /, then all remaining - with /
        var path = folderName
        path.removeFirst() // Remove leading dash
        path = "/" + path.replacingOccurrences(of: "-", with: "/")

        return path
    }

    /// Validates that a path exists and contains a .git folder
    /// - Parameter path: The file system path to validate
    /// - Returns: True if the path is a valid Git repository
    func isValidGitRepository(at path: String) -> Bool {
        var isDirectory: ObjCBool = false

        // Check if path exists and is a directory
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        // Check if .git folder exists
        let gitPath = "\(path)/.git"
        var gitIsDirectory: ObjCBool = false

        return fileManager.fileExists(atPath: gitPath, isDirectory: &gitIsDirectory) &&
               gitIsDirectory.boolValue
    }
}
