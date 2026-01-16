import Foundation

/// Service for discovering Claude Code and Codex projects
struct ClaudeProjectDiscoveryService {

    /// Represents a discovered project
    struct ClaudeProject {
        let path: String
        let name: String
        let source: ProjectSource
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Discovers all valid Claude Code and Codex projects
    /// - Returns: Array of valid Git project paths with their sources
    func discoverProjects() -> [ClaudeProject] {
        var allProjects: [ClaudeProject] = []

        // Discover Claude projects
        allProjects.append(contentsOf: discoverProjectsFrom(directory: getClaudeProjectsPath(), source: .claude))

        // Discover Codex projects
        allProjects.append(contentsOf: discoverProjectsFrom(directory: getCodexProjectsPath(), source: .codex))

        return allProjects
    }

    /// Discovers projects from a specific directory
    private func discoverProjectsFrom(directory: String, source: ProjectSource) -> [ClaudeProject] {
        guard fileManager.fileExists(atPath: directory) else {
            return []
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return []
        }

        return contents.compactMap { folderName -> ClaudeProject? in
            // Read the actual path from a JSONL file in the project folder
            let projectFolderPath = "\(directory)/\(folderName)"

            guard let actualPath = readActualPathFromJSONL(projectFolderPath: projectFolderPath) else {
                return nil
            }

            guard isValidGitRepository(at: actualPath) else {
                return nil
            }

            let projectName = URL(fileURLWithPath: actualPath).lastPathComponent
            return ClaudeProject(path: actualPath, name: projectName, source: source)
        }
    }

    /// Gets the path to the Claude projects directory
    /// - Returns: Path to ~/.claude/projects/
    func getClaudeProjectsPath() -> String {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser.path
        return "\(homeDirectory)/.claude/projects"
    }

    /// Gets the path to the Codex projects directory
    /// - Returns: Path to ~/.codex/projects/
    func getCodexProjectsPath() -> String {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser.path
        return "\(homeDirectory)/.codex/projects"
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

        // Check if .git exists (directory for standard repos, file for worktrees/submodules)
        let gitPath = "\(path)/.git"
        return fileManager.fileExists(atPath: gitPath)
    }

    /// Reads the actual project path from a JSONL file in the Claude project folder
    /// - Parameter projectFolderPath: Path to the Claude project folder
    /// - Returns: The actual project path, or nil if not found
    private func readActualPathFromJSONL(projectFolderPath: String) -> String? {
        // Get all JSONL files in the project folder
        guard let files = try? fileManager.contentsOfDirectory(atPath: projectFolderPath) else {
            return nil
        }

        let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }.sorted()

        // Try to find a JSON object containing a cwd field in any JSONL file.
        for jsonlFile in jsonlFiles {
            let fileURL = URL(fileURLWithPath: projectFolderPath).appendingPathComponent(jsonlFile)
            if let cwd = extractCwd(fromJSONLFile: fileURL) {
                return cwd
            }
        }

        return nil
    }

    /// Extracts a cwd value from a JSONL file by scanning the first N lines.
    private func extractCwd(fromJSONLFile fileURL: URL, maxLines: Int = 200) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }
        defer { try? handle.close() }

        let newline = Data([0x0A]) // \n
        let cwdKey = Data(#""cwd""#.utf8)

        var buffer = Data()
        var linesRead = 0

        while linesRead < maxLines {
            let chunk = handle.readData(ofLength: 64 * 1024)
            guard !chunk.isEmpty else { break } // EOF

            buffer.append(chunk)

            while linesRead < maxLines, let newlineRange = buffer.range(of: newline) {
                let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
                buffer.removeSubrange(0..<newlineRange.upperBound)
                linesRead += 1

                if let cwd = parseCwd(fromJSONLineData: lineData, cwdKey: cwdKey) {
                    return cwd
                }
            }
        }

        // EOF without a trailing newline.
        if linesRead < maxLines, !buffer.isEmpty {
            if let cwd = parseCwd(fromJSONLineData: buffer, cwdKey: cwdKey) {
                return cwd
            }
        }

        return nil
    }

    private func parseCwd(fromJSONLineData lineData: Data, cwdKey: Data) -> String? {
        var trimmed = lineData
        while trimmed.last == 0x0D { // \r
            trimmed.removeLast()
        }
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.range(of: cwdKey) != nil else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: trimmed) as? [String: Any],
              let cwd = json["cwd"] as? String,
              !cwd.isEmpty else {
            return nil
        }

        return cwd
    }
}
