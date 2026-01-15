import SwiftUI

/// Main view showing current branch, remote tracking status, and changed files
struct GitStatusView: View {
    let project: Project
    @StateObject private var viewModel = GitStatusViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with branch name and ahead/behind
            headerView

            Divider()
                .padding(.vertical, 8)

            // File changes or empty state
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if !viewModel.hasChanges {
                emptyStateView
            } else {
                changesListView
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.loadStatus(for: project.path)
        }
        .onChange(of: project.path) { newPath in
            viewModel.loadStatus(for: newPath)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundColor(.secondary)

            Text(viewModel.gitStatus?.currentBranch ?? "Loading...")
                .font(.headline)
                .fontWeight(.semibold)

            if let aheadBehind = viewModel.aheadBehindText {
                Text(aheadBehind)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }

            Spacer()

            Button(action: { viewModel.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh status")
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading...")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Error View

    private func errorView(error: Error) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.red)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.title)
                .foregroundColor(.green)
            Text("Working tree clean")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("No uncommitted changes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Changes List View

    private var changesListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Staged changes
                if !viewModel.stagedFiles.isEmpty {
                    FileGroupView(
                        title: "Staged",
                        files: viewModel.stagedFiles,
                        titleColor: .green
                    )
                }

                // Modified (unstaged) changes
                if !viewModel.modifiedFiles.isEmpty {
                    FileGroupView(
                        title: "Modified",
                        files: viewModel.modifiedFiles,
                        titleColor: .orange
                    )
                }

                // Untracked files
                if !viewModel.untrackedFiles.isEmpty {
                    FileGroupView(
                        title: "Untracked",
                        files: viewModel.untrackedFiles,
                        titleColor: .secondary
                    )
                }
            }
        }
    }
}

// MARK: - File Group View

/// A group of files with a header
struct FileGroupView: View {
    let title: String
    let files: [GitFileChange]
    let titleColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(titleColor)

                Text("(\(files.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(files, id: \.path) { file in
                FileRowView(file: file)
            }
        }
    }
}

// MARK: - File Row View

/// A single file change row
struct FileRowView: View {
    let file: GitFileChange

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Text(file.status.rawValue)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(statusColor)
                .frame(width: 16)

            // File path
            Text(file.path)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(4)
    }

    private var statusColor: Color {
        switch file.status {
        case .modified:
            return .orange
        case .added:
            return .green
        case .deleted:
            return .red
        case .renamed, .copied:
            return .blue
        case .untracked:
            return .secondary
        case .ignored:
            return .gray
        case .unmerged:
            return .purple
        case .typeChanged:
            return .cyan
        }
    }
}

#Preview {
    GitStatusView(project: Project(name: "Test Project", path: "/tmp/test"))
        .frame(width: 300, height: 400)
}
