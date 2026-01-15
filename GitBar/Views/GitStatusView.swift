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
        VStack(alignment: .leading, spacing: 8) {
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

            // Push/Pull buttons
            HStack(spacing: 8) {
                // Pull button
                Button(action: { viewModel.pull() }) {
                    HStack(spacing: 4) {
                        if viewModel.isPulling {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                        Text(viewModel.isPulling ? "Pulling..." : "Pull")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canPull)
                .help("Pull changes from remote")

                // Push button
                Button(action: { viewModel.push() }) {
                    HStack(spacing: 4) {
                        if viewModel.isPushing {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "arrow.up.circle")
                        }
                        Text(viewModel.isPushing ? "Pushing..." : "Push")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canPush)
                .help("Push commits to remote")

                Spacer()

                // Sync result feedback
                if let result = viewModel.syncResult {
                    syncFeedback(result)
                }
            }
        }
    }

    // MARK: - Sync Feedback

    private func syncFeedback(_ result: GitStatusViewModel.SyncResult) -> some View {
        HStack(spacing: 4) {
            switch result {
            case .pushSuccess:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Pushed!")
                    .font(.caption)
                    .foregroundColor(.green)
            case .pullSuccess:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Pulled!")
                    .font(.caption)
                    .foregroundColor(.green)
            case .failure(let error):
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
        .onAppear {
            // Auto-dismiss success feedback after 3 seconds
            if case .pushSuccess = result {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    viewModel.clearSyncResult()
                }
            } else if case .pullSuccess = result {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    viewModel.clearSyncResult()
                }
            }
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
                        titleColor: .green,
                        isStaged: true,
                        onStage: nil,
                        onUnstage: { filePath in viewModel.unstageFile(filePath) }
                    )
                }

                // Modified (unstaged) changes
                if !viewModel.modifiedFiles.isEmpty {
                    FileGroupView(
                        title: "Modified",
                        files: viewModel.modifiedFiles,
                        titleColor: .orange,
                        isStaged: false,
                        onStage: { filePath in viewModel.stageFile(filePath) },
                        onUnstage: nil
                    )
                }

                // Untracked files
                if !viewModel.untrackedFiles.isEmpty {
                    FileGroupView(
                        title: "Untracked",
                        files: viewModel.untrackedFiles,
                        titleColor: .secondary,
                        isStaged: false,
                        onStage: { filePath in viewModel.stageFile(filePath) },
                        onUnstage: nil
                    )
                }

                // Commit section (inline below file list)
                commitSection
            }
        }
    }

    // MARK: - Commit Section

    private var commitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 4)

            // Commit message text field
            TextField("Commit message", text: $viewModel.commitMessage)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .default))

            // Commit button and feedback
            HStack {
                Button(action: { viewModel.commit() }) {
                    HStack(spacing: 4) {
                        if viewModel.isCommitting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text(viewModel.isCommitting ? "Committing..." : "Commit")
                    }
                }
                .disabled(!viewModel.canCommit)
                .buttonStyle(.borderedProminent)

                Spacer()

                // Success/error feedback
                if let result = viewModel.commitResult {
                    commitFeedback(result)
                }
            }
        }
    }

    private func commitFeedback(_ result: GitStatusViewModel.CommitResult) -> some View {
        HStack(spacing: 4) {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Committed!")
                    .font(.caption)
                    .foregroundColor(.green)
            case .failure(let error):
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
        .onAppear {
            // Auto-dismiss success feedback after 3 seconds
            if case .success = result {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    viewModel.clearCommitResult()
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
    let isStaged: Bool
    let onStage: ((String) -> Void)?
    let onUnstage: ((String) -> Void)?

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
                FileRowView(
                    file: file,
                    isStaged: isStaged,
                    onStage: onStage,
                    onUnstage: onUnstage
                )
            }
        }
    }
}

// MARK: - File Row View

/// A single file change row
struct FileRowView: View {
    let file: GitFileChange
    let isStaged: Bool
    let onStage: ((String) -> Void)?
    let onUnstage: ((String) -> Void)?

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

            // Stage/Unstage button
            if isStaged {
                // Unstage button for staged files
                Button(action: { onUnstage?(file.path) }) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Unstage file")
            } else {
                // Stage button for unstaged/untracked files
                Button(action: { onStage?(file.path) }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Stage file")
            }
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
