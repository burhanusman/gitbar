import SwiftUI

/// A window that displays git diff output for a file
struct DiffViewer: View {
    let filePath: String
    let diff: String
    var onEdit: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var isEditHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textSecondary)

                Text(filePath)
                    .font(.system(size: Theme.fontBase, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Edit button
                if let onEdit = onEdit {
                    Button(action: {
                        dismiss()
                        onEdit()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .medium))
                            Text("Edit")
                                .font(.system(size: Theme.fontSM, weight: .medium))
                        }
                        .foregroundColor(isEditHovered ? Theme.textPrimary : Theme.textSecondary)
                        .padding(.horizontal, Theme.space3)
                        .padding(.vertical, 6)
                        .background(isEditHovered ? Theme.surfaceActive : Theme.surface)
                        .cornerRadius(Theme.radiusSmall)
                    }
                    .buttonStyle(.plain)
                    .onHover { isEditHovered = $0 }
                    .help("Edit file")
                    .pointingHandCursor()
                }

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                        .frame(width: 20, height: 20)
                        .background(Theme.surface)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, Theme.space4)
            .padding(.vertical, Theme.space3)
            .background(Theme.surfaceElevated)

            Divider()
                .background(Theme.border)

            // Diff content
            ScrollView([.horizontal, .vertical]) {
                if diff.isEmpty {
                    emptyView
                } else {
                    diffContent
                }
            }
            .background(Theme.background)
        }
        .frame(width: 700, height: 500)
    }

    private var emptyView: some View {
        VStack(spacing: Theme.space3) {
            Image(systemName: "doc.plaintext")
                .font(.system(size: 32))
                .foregroundColor(Theme.textTertiary)

            Text("No changes")
                .font(.system(size: Theme.fontBase))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var diffContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(diffLines.enumerated()), id: \.offset) { _, line in
                diffLine(line)
            }
        }
        .padding(Theme.space4)
    }

    private var diffLines: [String] {
        diff.components(separatedBy: .newlines)
    }

    private func diffLine(_ line: String) -> some View {
        HStack(alignment: .top, spacing: Theme.space2) {
            Text(line)
                .font(.system(size: Theme.fontSM, design: .monospaced))
                .foregroundColor(colorForLine(line))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .background(backgroundForLine(line))
    }

    private func colorForLine(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return Theme.success
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return Theme.error
        } else if line.hasPrefix("@@") {
            return Theme.accent
        } else if line.hasPrefix("diff ") || line.hasPrefix("index ") || line.hasPrefix("+++") || line.hasPrefix("---") {
            return Theme.textMuted
        } else {
            return Theme.textSecondary
        }
    }

    private func backgroundForLine(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return Theme.success.opacity(0.1)
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return Theme.error.opacity(0.1)
        } else {
            return .clear
        }
    }
}

#Preview {
    DiffViewer(
        filePath: "GitBar/Views/GitStatusView.swift",
        diff: """
        diff --git a/GitBar/Views/GitStatusView.swift b/GitBar/Views/GitStatusView.swift
        index 1234567..abcdefg 100644
        --- a/GitBar/Views/GitStatusView.swift
        +++ b/GitBar/Views/GitStatusView.swift
        @@ -1,7 +1,7 @@
         import SwiftUI

        -struct GitStatusView: View {
        +struct GitStatusView: View, Observable {
             let project: Project
             @StateObject private var viewModel = GitStatusViewModel()
        """
    )
}
