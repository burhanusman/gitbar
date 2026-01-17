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
                .padding(.top, 16)
                .padding(.bottom, 12)

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
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.loadStatus(for: project.path)
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .onChange(of: project.path) { newPath in
            viewModel.loadStatus(for: newPath)
            viewModel.startAutoRefresh()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Menu {
                    if viewModel.branches.isEmpty {
                        Text("No local branches")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.branches, id: \.self) { branch in
                            Button(action: { viewModel.checkoutBranch(branch) }) {
                                if branch == viewModel.gitStatus?.currentBranch {
                                    Label(branch, systemImage: "checkmark")
                                } else {
                                    Text(branch)
                                }
                            }
                            .disabled(viewModel.isSwitchingBranch)
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(branchLabel)
                            .font(.system(size: 14, weight: .semibold))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)

                        if viewModel.isSwitchingBranch {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                    }
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .help("Switch branch")

                if let aheadBehind = viewModel.aheadBehindText {
                    Text(aheadBehind)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "#0A84FF"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#0A84FF").opacity(0.12))
                        .cornerRadius(4)
                }

                Spacer()

                if viewModel.worktrees.count > 1 {
                    Menu {
                        ForEach(viewModel.worktrees) { worktree in
                            Button(action: { viewModel.switchToWorktree(at: worktree.path) }) {
                                if worktree.path == viewModel.activePath {
                                    Label(worktreeLabel(for: worktree), systemImage: "checkmark")
                                } else {
                                    Text(worktreeLabel(for: worktree))
                                }
                            }
                            .disabled(worktree.path == viewModel.activePath)
                        }
                    } label: {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .help("Switch worktree")
                }

                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh status")
            }

            // Push/Pull buttons
            HStack(spacing: 8) {
                // Pull button
                TactileButton(
                    action: { viewModel.pull() },
                    isDisabled: !viewModel.canPull,
                    helpText: "Pull changes from remote"
                ) {
                    HStack(spacing: 5) {
                        if viewModel.isPulling {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 12))
                        }
                        Text(viewModel.isPulling ? "Pulling..." : "Pull")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }

                // Push button
                TactileButton(
                    action: { viewModel.push() },
                    isDisabled: !viewModel.canPush,
                    helpText: "Push commits to remote"
                ) {
                    HStack(spacing: 5) {
                        if viewModel.isPushing {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            Image(systemName: "arrow.up.circle")
                                .font(.system(size: 12))
                        }
                        Text(viewModel.isPushing ? "Pushing..." : "Push")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }

                Spacer()

                // Sync result feedback
                if let result = viewModel.syncResult {
                    syncFeedback(result)
                }
            }
        }
    }

    private var branchLabel: String {
        if viewModel.gitStatus == nil {
            return "Loading..."
        }
        return viewModel.gitStatus?.currentBranch ?? "Detached HEAD"
    }

    private func worktreeLabel(for worktree: GitWorktree) -> String {
        let name = URL(fileURLWithPath: worktree.path).lastPathComponent
        let branch = worktree.branch ?? (worktree.isDetached ? "detached" : "unknown")
        return "\(name) · \(branch)"
    }

    // MARK: - Sync Feedback

    private func syncFeedback(_ result: GitStatusViewModel.SyncResult) -> some View {
        HStack(spacing: 6) {
            switch result {
            case .pushSuccess:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#30D158"))
                Text("Pushed!")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#30D158"))
            case .pullSuccess:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#30D158"))
                Text("Pulled!")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#30D158"))
            case .failure(let error):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FF453A"))
                Text(error.localizedDescription)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#FF453A"))
                    .lineLimit(1)
            }
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .opacity
        ))
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
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 30)
    }

    // MARK: - Error View

    private func errorView(error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(Color(hex: "#FF453A"))
            Text(error.localizedDescription)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        EmptyStateAnimatedView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
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
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Commit message text field
            TextField("Commit message", text: $viewModel.commitMessage)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            // Commit button and feedback
            HStack(spacing: 12) {
                Button(action: { viewModel.commit() }) {
                    HStack(spacing: 5) {
                        if viewModel.isCommitting {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                        Text(viewModel.isCommitting ? "Committing..." : "Commit")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .disabled(!viewModel.canCommit)
                .buttonStyle(.borderless)
                .background(viewModel.canCommit ? Color(hex: "#0A84FF") : Color(hex: "#2a2a2a"))
                .foregroundColor(viewModel.canCommit ? .white : .secondary)
                .cornerRadius(5)

                // Success/error feedback
                if let result = viewModel.commitResult {
                    commitFeedback(result)
                }

                Spacer()
            }
        }
    }

    private func commitFeedback(_ result: GitStatusViewModel.CommitResult) -> some View {
        HStack(spacing: 6) {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#30D158"))
                Text("Committed!")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#30D158"))
            case .failure(let error):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FF453A"))
                Text(error.localizedDescription)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#FF453A"))
                    .lineLimit(1)
            }
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .opacity
        ))
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(titleColor)

                Text("\(files.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#1a1a1a"))
                    .cornerRadius(4)
            }
            .padding(.bottom, 2)

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
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator
            Text(file.status.rawValue)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(statusColor)
                .frame(width: 14, alignment: .center)

            // File path
            Text(file.path)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            // Stage/Unstage button (only visible on hover)
            if isHovering {
                if isStaged {
                    // Unstage button for staged files
                    Button(action: { onUnstage?(file.path) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Unstage file")
                } else {
                    // Stage button for unstaged/untracked files
                    Button(action: { onStage?(file.path) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Stage file")
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(isHovering ? Color(hex: "#2a2a2a") : Color(hex: "#1a1a1a").opacity(0.4))
        .cornerRadius(6)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var statusColor: Color {
        switch file.status {
        case .modified:
            return Color(hex: "#0A84FF")
        case .added:
            return Color(hex: "#30D158")
        case .deleted:
            return Color(hex: "#FF453A")
        case .renamed, .copied:
            return Color(hex: "#0A84FF")
        case .untracked:
            return .secondary
        case .ignored:
            return .secondary
        case .unmerged:
            return Color(hex: "#BF5AF2")
        case .typeChanged:
            return Color(hex: "#64D2FF")
        }
    }
}

// MARK: - Tactile Button

/// Button with satisfying press feedback
struct TactileButton<Content: View>: View {
    let action: () -> Void
    let isDisabled: Bool
    let helpText: String
    let content: () -> Content

    @State private var isPressed = false
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            content()
        }
        .buttonStyle(TactileButtonStyle(isPressed: $isPressed, isHovering: $isHovering))
        .background(Color(hex: "#2a2a2a"))
        .cornerRadius(6)
        .scaleEffect(isPressed ? 0.96 : (isHovering ? 1.02 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .help(helpText)
        .onHover { hovering in
            isHovering = hovering && !isDisabled
        }
    }
}

struct TactileButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    @Binding var isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { pressed in
                isPressed = pressed
            }
    }
}

// MARK: - Empty State Animated View

/// Refined animated empty state for clean working tree
struct EmptyStateAnimatedView: View {
    @State private var isAnimating = false
    @State private var showText = false
    @State private var pulseScale = 1.0

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Subtle pulse ring
                Circle()
                    .stroke(Color(hex: "#30D158").opacity(0.15), lineWidth: 1.5)
                    .frame(width: 48, height: 48)
                    .scaleEffect(pulseScale)
                    .opacity(2.0 - pulseScale)

                // Main checkmark circle
                ZStack {
                    Circle()
                        .fill(Color(hex: "#30D158").opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: "#30D158"))
                        .scaleEffect(isAnimating ? 1.0 : 0.0)
                        .rotationEffect(.degrees(isAnimating ? 0 : -45))
                }
            }
            .frame(height: 52)

            VStack(spacing: 4) {
                Text("All clear")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .opacity(showText ? 1.0 : 0.0)
                    .offset(y: showText ? 0 : 6)

                Text("No uncommitted changes")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .opacity(showText ? 1.0 : 0.0)
                    .offset(y: showText ? 0 : 6)
            }
        }
        .onAppear {
            // Checkmark entrance with spring
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                isAnimating = true
            }

            // Subtle pulse animation
            withAnimation(
                .easeInOut(duration: 2.5)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.15
            }

            // Text fade in with slight delay
            withAnimation(.easeOut(duration: 0.35).delay(0.15)) {
                showText = true
            }
        }
    }
}

#Preview {
    GitStatusView(project: Project(name: "Test Project", path: "/tmp/test"))
        .frame(width: 300, height: 400)
}
