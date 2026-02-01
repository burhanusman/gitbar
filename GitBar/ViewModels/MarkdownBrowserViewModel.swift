import Foundation
import os.log

private let logger = Logger(subsystem: "com.gitbar.app", category: "MarkdownBrowser")

/// ViewModel for discovering and listing all markdown files in a repository
@MainActor
class MarkdownBrowserViewModel: ObservableObject {
    @Published var markdownFiles: [FileNode] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let fileService = FileService()
    private var repoPath: String?

    /// Markdown file extensions to match
    private let markdownExtensions: Set<String> = ["md", "markdown"]

    /// Loads all markdown files from the given repo path
    func loadMarkdownFiles(at path: String) {
        logger.info("📝 loadMarkdownFiles START: \(path)")
        repoPath = path
        isLoading = true
        error = nil

        Task {
            do {
                let files = try await scanForMarkdownFiles(at: path)
                self.markdownFiles = files.sorted { lhs, rhs in
                    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                self.isLoading = false
                logger.info("📝 loadMarkdownFiles DONE: \(files.count) files found")
            } catch {
                logger.error("📝 loadMarkdownFiles ERROR: \(error.localizedDescription)")
                self.error = error
                self.isLoading = false
            }
        }
    }

    /// Refreshes the markdown file list
    func refresh() {
        guard let path = repoPath else { return }
        loadMarkdownFiles(at: path)
    }

    /// Returns the relative path of a file from the repo root (directory portion only)
    func relativePath(for file: FileNode) -> String? {
        guard let repoPath = repoPath else { return nil }
        let fullDir = (file.path as NSString).deletingLastPathComponent
        guard fullDir.hasPrefix(repoPath) else { return nil }
        var relative = String(fullDir.dropFirst(repoPath.count))
        if relative.hasPrefix("/") {
            relative = String(relative.dropFirst())
        }
        return relative.isEmpty ? nil : relative
    }

    // MARK: - Private

    /// Recursively scans for markdown files, respecting excluded directories
    private func scanForMarkdownFiles(at path: String) async throws -> [FileNode] {
        let contents = try await fileService.listDirectory(at: path)
        var results: [FileNode] = []

        for node in contents {
            if node.isDirectory {
                // Recurse into subdirectories (listDirectory already excludes node_modules, .git, etc.)
                if let children = try? await scanForMarkdownFiles(at: node.path) {
                    results.append(contentsOf: children)
                }
            } else {
                let ext = (node.name as NSString).pathExtension.lowercased()
                if markdownExtensions.contains(ext) {
                    results.append(node)
                }
            }
        }

        return results
    }
}
