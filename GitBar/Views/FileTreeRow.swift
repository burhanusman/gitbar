import SwiftUI

/// A row component for displaying a file or folder in the tree
struct FileTreeRow: View {
    let node: FileNode
    let depth: Int
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onSelect: () -> Void

    @State private var isHovered = false

    private let indentWidth: CGFloat = 16

    var body: some View {
        HStack(spacing: Theme.space2) {
            // Indentation
            HStack(spacing: 0) {
                ForEach(0..<depth, id: \.self) { _ in
                    Color.clear
                        .frame(width: indentWidth)
                }
            }

            // Expand/collapse chevron for directories
            if node.isDirectory {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 12, height: 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: Theme.animationFast)) {
                            onToggleExpand()
                        }
                    }
            } else {
                Color.clear
                    .frame(width: 12, height: 12)
            }

            // File/folder icon
            Image(systemName: node.iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 16, height: 16)

            // File name
            Text(node.name)
                .font(.system(size: Theme.fontSM, design: node.isDirectory ? .default : .monospaced))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: Theme.space2)

            // Git status badge
            if let status = node.gitStatus {
                gitStatusBadge(status)
            }
        }
        .padding(.horizontal, Theme.space3)
        .padding(.vertical, 6)
        .background(isHovered ? Theme.surfaceHover : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            if node.isDirectory {
                withAnimation(.easeOut(duration: Theme.animationFast)) {
                    onToggleExpand()
                }
            } else {
                onSelect()
            }
        }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
        .pointingHandCursor()
    }

    private var iconColor: Color {
        if node.isDirectory {
            return Theme.accent
        }

        // Color based on file extension
        switch node.fileExtension {
        case "swift":
            return Color(hex: "#F05138") // Swift orange
        case "js", "jsx", "ts", "tsx":
            return Color(hex: "#F7DF1E") // JS yellow
        case "py":
            return Color(hex: "#3776AB") // Python blue
        case "rb":
            return Color(hex: "#CC342D") // Ruby red
        case "go":
            return Color(hex: "#00ADD8") // Go cyan
        case "rs":
            return Color(hex: "#DEA584") // Rust orange
        case "json", "yaml", "yml", "toml":
            return Theme.textTertiary
        case "md", "markdown":
            return Theme.textSecondary
        case "gitignore", "gitattributes":
            return Theme.warning
        default:
            return Theme.textSecondary
        }
    }

    private func gitStatusBadge(_ status: GitFileChange.Status) -> some View {
        Text(statusLetter(status))
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(statusColor(status))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.15))
            .cornerRadius(4)
    }

    private func statusLetter(_ status: GitFileChange.Status) -> String {
        switch status {
        case .modified: return "M"
        case .added: return "A"
        case .deleted: return "D"
        case .renamed: return "R"
        case .copied: return "C"
        case .untracked: return "?"
        case .ignored: return "!"
        case .unmerged: return "U"
        case .typeChanged: return "T"
        }
    }

    private func statusColor(_ status: GitFileChange.Status) -> Color {
        switch status {
        case .modified: return Theme.warning
        case .added: return Theme.success
        case .deleted: return Theme.error
        case .untracked: return Theme.textTertiary
        case .unmerged: return Color(hex: "#BF5AF2") // Purple
        default: return Theme.textSecondary
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        FileTreeRow(
            node: FileNode(name: "src", path: "/src", isDirectory: true),
            depth: 0,
            isExpanded: true,
            onToggleExpand: {},
            onSelect: {}
        )

        FileTreeRow(
            node: FileNode(name: "App.swift", path: "/src/App.swift", isDirectory: false, gitStatus: .modified),
            depth: 1,
            isExpanded: false,
            onToggleExpand: {},
            onSelect: {}
        )

        FileTreeRow(
            node: FileNode(name: "NewFile.swift", path: "/src/NewFile.swift", isDirectory: false, gitStatus: .added),
            depth: 1,
            isExpanded: false,
            onToggleExpand: {},
            onSelect: {}
        )

        FileTreeRow(
            node: FileNode(name: "README.md", path: "/README.md", isDirectory: false),
            depth: 0,
            isExpanded: false,
            onToggleExpand: {},
            onSelect: {}
        )
    }
    .background(Theme.background)
}
