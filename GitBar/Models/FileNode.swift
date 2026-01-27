import Foundation

/// Represents a node in the file tree (file or directory)
struct FileNode: Identifiable, Equatable {
    let id: String  // Full path
    let name: String
    let path: String
    let isDirectory: Bool
    var children: [FileNode]?
    var gitStatus: GitFileChange.Status?
    var isExpanded: Bool = false

    /// Creates a FileNode from a path
    init(name: String, path: String, isDirectory: Bool, children: [FileNode]? = nil, gitStatus: GitFileChange.Status? = nil) {
        self.id = path
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
        self.gitStatus = gitStatus
    }

    /// Returns the file extension (lowercase, without dot)
    var fileExtension: String? {
        guard !isDirectory else { return nil }
        let ext = (name as NSString).pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }

    /// Returns the appropriate SF Symbol name for this file type
    var iconName: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }

        guard let ext = fileExtension else {
            return "doc"
        }

        switch ext {
        // Swift/iOS
        case "swift":
            return "swift"
        case "xcodeproj", "xcworkspace":
            return "hammer"

        // Web
        case "js", "jsx", "ts", "tsx":
            return "curlybraces"
        case "html", "htm":
            return "globe"
        case "css", "scss", "sass", "less":
            return "paintbrush"
        case "json":
            return "curlybraces.square"

        // Languages
        case "py":
            return "chevron.left.forwardslash.chevron.right"
        case "rb":
            return "rhombus"
        case "go":
            return "chevron.left.forwardslash.chevron.right"
        case "rs":
            return "gearshape"
        case "java", "kt", "kts":
            return "cup.and.saucer"
        case "c", "h":
            return "c.square"
        case "cpp", "cc", "cxx", "hpp":
            return "c.square.fill"
        case "cs":
            return "number.square"

        // Config/Data
        case "yaml", "yml":
            return "list.bullet"
        case "toml":
            return "list.bullet"
        case "xml":
            return "chevron.left.forwardslash.chevron.right"
        case "plist":
            return "list.bullet.rectangle"

        // Docs
        case "md", "markdown":
            return "doc.richtext"
        case "txt":
            return "doc.text"
        case "pdf":
            return "doc.text.fill"

        // Images
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "ico":
            return "photo"

        // Shell/Scripts
        case "sh", "bash", "zsh":
            return "terminal"

        // Git
        case "gitignore", "gitattributes":
            return "arrow.triangle.branch"

        // Lock files
        case "lock":
            return "lock"

        default:
            return "doc"
        }
    }

    static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.isDirectory == rhs.isDirectory &&
        lhs.gitStatus == rhs.gitStatus &&
        lhs.isExpanded == rhs.isExpanded &&
        lhs.children == rhs.children
    }
}
