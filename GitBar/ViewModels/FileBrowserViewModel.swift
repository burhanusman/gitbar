import Foundation
import SwiftUI

/// ViewModel for managing the file browser state
@MainActor
class FileBrowserViewModel: ObservableObject {
    @Published var rootNode: FileNode?
    @Published var expandedPaths: Set<String> = []
    @Published var selectedFile: FileNode?
    @Published var isLoading = false
    @Published var error: Error?

    private let fileService = FileService()
    private var repoPath: String?
    private var gitStatusMap: [String: GitFileChange.Status] = [:]

    /// Loads the root directory for the given repo path
    func loadDirectory(at path: String) {
        repoPath = path
        isLoading = true
        error = nil

        Task {
            do {
                let nodes = try await fileService.listDirectory(at: path)
                self.rootNode = FileNode(
                    name: (path as NSString).lastPathComponent,
                    path: path,
                    isDirectory: true,
                    children: nodes
                )
                self.isLoading = false
            } catch {
                self.error = error
                self.isLoading = false
            }
        }
    }

    /// Refreshes the current directory
    func refresh() {
        guard let path = repoPath else { return }
        loadDirectory(at: path)
    }

    /// Toggles the expansion state of a directory node
    func toggleExpand(for node: FileNode) {
        guard node.isDirectory else { return }

        if expandedPaths.contains(node.path) {
            expandedPaths.remove(node.path)
        } else {
            expandedPaths.insert(node.path)

            // Load children if not already loaded
            if findNode(at: node.path)?.children == nil {
                loadChildren(for: node.path)
            }
        }
    }

    /// Checks if a path is expanded
    func isExpanded(_ path: String) -> Bool {
        expandedPaths.contains(path)
    }

    /// Loads children for a directory node
    private func loadChildren(for path: String) {
        Task {
            do {
                let children = try await fileService.listDirectory(at: path)
                await updateChildren(for: path, with: children)
            } catch {
                self.error = error
            }
        }
    }

    /// Updates children of a node at the given path
    private func updateChildren(for path: String, with children: [FileNode]) async {
        guard var root = rootNode else { return }

        // Apply git status to children
        var updatedChildren = children
        for i in updatedChildren.indices {
            let relativePath = makeRelativePath(updatedChildren[i].path)
            updatedChildren[i].gitStatus = gitStatusMap[relativePath]
        }

        if path == root.path {
            root.children = updatedChildren
            rootNode = root
        } else {
            updateChildrenRecursive(in: &root, targetPath: path, newChildren: updatedChildren)
            rootNode = root
        }
    }

    /// Recursively updates children in the tree
    private func updateChildrenRecursive(in node: inout FileNode, targetPath: String, newChildren: [FileNode]) {
        guard var children = node.children else { return }

        for i in children.indices {
            if children[i].path == targetPath {
                children[i].children = newChildren
                node.children = children
                return
            } else if children[i].isDirectory {
                updateChildrenRecursive(in: &children[i], targetPath: targetPath, newChildren: newChildren)
            }
        }
        node.children = children
    }

    /// Finds a node at the given path
    private func findNode(at path: String) -> FileNode? {
        guard let root = rootNode else { return nil }
        return findNodeRecursive(in: root, path: path)
    }

    private func findNodeRecursive(in node: FileNode, path: String) -> FileNode? {
        if node.path == path {
            return node
        }

        guard let children = node.children else { return nil }

        for child in children {
            if let found = findNodeRecursive(in: child, path: path) {
                return found
            }
        }

        return nil
    }

    /// Returns the flattened list of visible nodes for display
    func visibleNodes(from node: FileNode? = nil, depth: Int = 0) -> [(node: FileNode, depth: Int)] {
        guard let node = node ?? rootNode else { return [] }
        guard let children = node.children else { return [] }

        var result: [(node: FileNode, depth: Int)] = []

        for child in children {
            result.append((child, depth))

            if child.isDirectory && isExpanded(child.path) {
                result.append(contentsOf: visibleNodes(from: child, depth: depth + 1))
            }
        }

        return result
    }

    /// Updates git status for files in the tree
    func refreshGitStatus(from gitStatus: GitStatus?) {
        guard let changes = gitStatus?.changes else {
            gitStatusMap = [:]
            return
        }

        gitStatusMap = [:]
        for change in changes {
            gitStatusMap[change.path] = change.status
        }

        // Update the tree with new status
        if var root = rootNode {
            updateGitStatusRecursive(in: &root)
            rootNode = root
        }
    }

    /// Recursively updates git status in the tree
    private func updateGitStatusRecursive(in node: inout FileNode) {
        let relativePath = makeRelativePath(node.path)
        node.gitStatus = gitStatusMap[relativePath]

        guard var children = node.children else { return }

        for i in children.indices {
            updateGitStatusRecursive(in: &children[i])
        }
        node.children = children
    }

    /// Makes a path relative to the repo root
    private func makeRelativePath(_ fullPath: String) -> String {
        guard let repoPath = repoPath else { return fullPath }
        if fullPath.hasPrefix(repoPath) {
            var relative = String(fullPath.dropFirst(repoPath.count))
            if relative.hasPrefix("/") {
                relative = String(relative.dropFirst())
            }
            return relative
        }
        return fullPath
    }
}
