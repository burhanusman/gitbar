import SwiftUI

/// Main view for browsing files in the repository
struct FileBrowserView: View {
    let project: Project
    @StateObject private var viewModel = FileBrowserViewModel()
    @State private var selectedFileForEditing: FileNode?
    @State private var gitStatusViewModel: GitStatusViewModel?

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
            } else if viewModel.rootNode == nil {
                emptyStateView
            } else {
                fileTreeView
            }
        }
        .background(Theme.background)
        .onAppear {
            viewModel.loadDirectory(at: project.path)
        }
        .onChange(of: project.path) { newPath in
            viewModel.loadDirectory(at: newPath)
        }
        .sheet(item: $selectedFileForEditing) { file in
            FileEditorView(filePath: file.path, repoPath: project.path)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: Theme.space3) {
            Image(systemName: "folder")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.accent)

            Text("Files")
                .font(.system(size: Theme.fontLG, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

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

    // MARK: - File Tree

    private var fileTreeView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.visibleNodes(), id: \.node.id) { item in
                    FileTreeRow(
                        node: item.node,
                        depth: item.depth,
                        isExpanded: viewModel.isExpanded(item.node.path),
                        onToggleExpand: {
                            viewModel.toggleExpand(for: item.node)
                        },
                        onSelect: {
                            if !item.node.isDirectory {
                                selectedFileForEditing = item.node
                            }
                        }
                    )

                    if item.node.id != viewModel.visibleNodes().last?.node.id {
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
            Text("Loading files...")
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
                Text("Failed to load files")
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

                Image(systemName: "folder")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
            }

            VStack(spacing: Theme.space2) {
                Text("No files")
                    .font(.system(size: Theme.fontLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text("This directory appears to be empty")
                    .font(.system(size: Theme.fontBase))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    FileBrowserView(project: Project(name: "Demo", path: "/Users"))
        .frame(width: 500, height: 400)
}
