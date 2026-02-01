import SwiftUI

/// View for browsing markdown files in a repository
struct MarkdownBrowserView: View {
    let project: Project
    @StateObject private var viewModel = MarkdownBrowserViewModel()
    @State private var selectedFileForEditing: FileNode?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, Theme.space6)
                .padding(.vertical, Theme.space4)
                .background(Theme.surfaceElevated)

            Divider()
                .background(Theme.border)

            // Content
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if viewModel.markdownFiles.isEmpty {
                emptyStateView
            } else {
                fileListView
            }
        }
        .background(Theme.background)
        .onAppear {
            viewModel.loadMarkdownFiles(at: project.path)
        }
        .onChange(of: project.path) { newPath in
            viewModel.loadMarkdownFiles(at: newPath)
        }
        .sheet(item: $selectedFileForEditing) { file in
            FileEditorView(filePath: file.path, repoPath: project.path, initialMode: .preview)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: Theme.space3) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.accent)

            Text(".md Files")
                .font(.system(size: Theme.fontLG, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            // File count badge
            if !viewModel.markdownFiles.isEmpty {
                Text("\(viewModel.markdownFiles.count)")
                    .font(.system(size: Theme.fontXS, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accentMuted)
                    .cornerRadius(4)
            }

            Spacer()

            // Refresh button
            Button(action: {
                viewModel.refresh()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: Theme.fontSM, weight: .medium))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 24, height: 24)
                    .background(Theme.surface)
                    .cornerRadius(Theme.radiusSmall)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .help("Refresh")
            .pointingHandCursor()
        }
    }

    // MARK: - File List

    private var fileListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.markdownFiles.enumerated()), id: \.element.id) { index, file in
                    MarkdownFileRow(
                        file: file,
                        relativePath: viewModel.relativePath(for: file),
                        onSelect: {
                            selectedFileForEditing = file
                        }
                    )

                    if index < viewModel.markdownFiles.count - 1 {
                        Divider()
                            .background(Theme.border.opacity(0.5))
                    }
                }
            }
            .padding(.vertical, Theme.space2)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: Theme.space4) {
            ProgressView()
                .scaleEffect(0.9)
            Text("Scanning for markdown files...")
                .font(.system(size: Theme.fontBase))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: Theme.space4) {
            ZStack {
                Circle()
                    .fill(Theme.errorMuted)
                    .frame(width: 64, height: 64)

                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Theme.error)
            }

            VStack(spacing: Theme.space2) {
                Text("Failed to scan files")
                    .font(.system(size: Theme.fontLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text(error.localizedDescription)
                    .font(.system(size: Theme.fontBase))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.space8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: Theme.space5) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceHover)
                    .frame(width: 72, height: 72)

                Image(systemName: "doc.richtext")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
            }

            VStack(spacing: Theme.space2) {
                Text("No markdown files")
                    .font(.system(size: Theme.fontLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text("This repository has no .md or .markdown files")
                    .font(.system(size: Theme.fontBase))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Markdown File Row

struct MarkdownFileRow: View {
    let file: FileNode
    let relativePath: String?
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Theme.space3) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.accent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.system(size: Theme.fontSM, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    if let path = relativePath {
                        Text(path)
                            .font(.system(size: Theme.fontXS, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.horizontal, Theme.space4)
            .padding(.vertical, Theme.space3)
            .background(isHovered ? Theme.surfaceHover : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointingHandCursor()
    }
}

#Preview {
    MarkdownBrowserView(project: Project(name: "Demo", path: "/Users"))
        .frame(width: 500, height: 400)
}
