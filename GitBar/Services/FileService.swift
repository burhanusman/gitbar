import Foundation

/// Errors that can occur during file operations
enum FileServiceError: Error, LocalizedError {
    case fileNotFound(String)
    case directoryNotFound(String)
    case readFailed(String)
    case writeFailed(String)
    case fileTooLarge(String, Int)
    case binaryFile(String)
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .readFailed(let message):
            return "Failed to read file: \(message)"
        case .writeFailed(let message):
            return "Failed to write file: \(message)"
        case .fileTooLarge(let path, let size):
            return "File too large (\(size / 1024)KB): \(path)"
        case .binaryFile(let path):
            return "Binary file cannot be edited: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        }
    }
}

/// Service for file system operations
actor FileService {
    private let fileManager: FileManager

    /// Maximum file size for reading (1MB)
    private let maxFileSize = 1_048_576

    /// Common binary file extensions
    private let binaryExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "ico", "bmp", "tiff", "tif",
        "mp3", "mp4", "wav", "flac", "ogg", "avi", "mov", "mkv", "webm",
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "zip", "tar", "gz", "rar", "7z", "bz2",
        "exe", "dll", "so", "dylib", "app", "dmg",
        "ttf", "otf", "woff", "woff2", "eot",
        "sqlite", "db", "realm",
        "o", "a", "class", "pyc", "pyo"
    ]

    /// Directories to exclude from file listing
    private let excludedDirectories: Set<String> = [
        ".git", ".svn", ".hg",
        "node_modules", "Pods", "DerivedData",
        ".build", "build", "dist", "out",
        "__pycache__", ".pytest_cache", ".mypy_cache",
        ".idea", ".vscode",
        "Carthage"
    ]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Directory Listing

    /// Lists the contents of a directory and returns FileNode objects
    func listDirectory(at path: String, includeHidden: Bool = false) async throws -> [FileNode] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileServiceError.directoryNotFound(path)
        }

        let contents = try fileManager.contentsOfDirectory(atPath: path)

        var nodes: [FileNode] = []

        for name in contents {
            // Skip hidden files unless requested
            if !includeHidden && name.hasPrefix(".") {
                continue
            }

            // Skip excluded directories
            if excludedDirectories.contains(name) {
                continue
            }

            let fullPath = (path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false

            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) {
                let node = FileNode(
                    name: name,
                    path: fullPath,
                    isDirectory: isDir.boolValue
                )
                nodes.append(node)
            }
        }

        // Sort: directories first, then alphabetically
        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Recursively lists directory contents up to a specified depth
    func listDirectoryRecursive(at path: String, maxDepth: Int = 1, currentDepth: Int = 0, includeHidden: Bool = false) async throws -> [FileNode] {
        guard currentDepth < maxDepth else {
            return try await listDirectory(at: path, includeHidden: includeHidden)
        }

        var nodes = try await listDirectory(at: path, includeHidden: includeHidden)

        for i in nodes.indices {
            if nodes[i].isDirectory {
                let children = try? await listDirectoryRecursive(
                    at: nodes[i].path,
                    maxDepth: maxDepth,
                    currentDepth: currentDepth + 1,
                    includeHidden: includeHidden
                )
                nodes[i].children = children
            }
        }

        return nodes
    }

    // MARK: - File Reading

    /// Reads the content of a file as a string
    func readFile(at path: String) async throws -> String {
        guard fileManager.fileExists(atPath: path) else {
            throw FileServiceError.fileNotFound(path)
        }

        // Check if it's a binary file
        let ext = (path as NSString).pathExtension.lowercased()
        if binaryExtensions.contains(ext) {
            throw FileServiceError.binaryFile(path)
        }

        // Check file size
        let attributes = try fileManager.attributesOfItem(atPath: path)
        if let size = attributes[.size] as? Int, size > maxFileSize {
            throw FileServiceError.fileTooLarge(path, size)
        }

        // Read file
        guard let data = fileManager.contents(atPath: path) else {
            throw FileServiceError.readFailed("Could not read file data")
        }

        // Try to decode as UTF-8
        guard let content = String(data: data, encoding: .utf8) else {
            // Try other encodings
            if let content = String(data: data, encoding: .ascii) {
                return content
            }
            if let content = String(data: data, encoding: .isoLatin1) {
                return content
            }
            throw FileServiceError.binaryFile(path)
        }

        return content
    }

    /// Checks if a file is readable (not binary and not too large)
    func isFileReadable(at path: String) -> Bool {
        guard fileManager.fileExists(atPath: path) else {
            return false
        }

        let ext = (path as NSString).pathExtension.lowercased()
        if binaryExtensions.contains(ext) {
            return false
        }

        if let attributes = try? fileManager.attributesOfItem(atPath: path),
           let size = attributes[.size] as? Int,
           size > maxFileSize {
            return false
        }

        return true
    }

    // MARK: - File Writing

    /// Writes content to a file
    func writeFile(content: String, to path: String) async throws {
        guard let data = content.data(using: .utf8) else {
            throw FileServiceError.writeFailed("Could not encode content as UTF-8")
        }

        // Check if we have write permission
        let parentDir = (path as NSString).deletingLastPathComponent
        guard fileManager.isWritableFile(atPath: parentDir) else {
            throw FileServiceError.permissionDenied(path)
        }

        // Write atomically to prevent data loss
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            throw FileServiceError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - File Info

    /// Gets basic file information
    func getFileInfo(at path: String) async throws -> FileInfo {
        guard fileManager.fileExists(atPath: path) else {
            throw FileServiceError.fileNotFound(path)
        }

        let attributes = try fileManager.attributesOfItem(atPath: path)

        return FileInfo(
            path: path,
            name: (path as NSString).lastPathComponent,
            size: attributes[.size] as? Int ?? 0,
            modificationDate: attributes[.modificationDate] as? Date,
            isReadable: isFileReadable(at: path)
        )
    }
}

/// Information about a file
struct FileInfo {
    let path: String
    let name: String
    let size: Int
    let modificationDate: Date?
    let isReadable: Bool

    var formattedSize: String {
        if size < 1024 {
            return "\(size) B"
        } else if size < 1_048_576 {
            return String(format: "%.1f KB", Double(size) / 1024)
        } else {
            return String(format: "%.1f MB", Double(size) / 1_048_576)
        }
    }
}
