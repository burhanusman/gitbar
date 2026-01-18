import SwiftUI
import AppKit

/// Main view showing current branch, remote tracking status, and changed files
struct GitStatusView: View {
    let project: Project
    @StateObject private var viewModel = GitStatusViewModel()

    @State private var fileToDiscard: String?
    @State private var showDiscardAllConfirmation = false
    @State private var showCopiedFeedback = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with branch name and actions
            headerView
                .padding(.horizontal, Theme.paddingLarge)
                .padding(.vertical, Theme.paddingMedium)
                .background(Theme.surface.opacity(0.5))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Theme.border),
                    alignment: .bottom
                )

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
        .background(Theme.background)
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
        .alert("Discard Changes?", isPresented: Binding<Bool>(
            get: { fileToDiscard != nil || showDiscardAllConfirmation },
            set: { if !$0 { fileToDiscard = nil; showDiscardAllConfirmation = false } }
        )) {
            Button("Cancel", role: .cancel) {
                fileToDiscard = nil
                showDiscardAllConfirmation = false
            }
            Button("Discard", role: .destructive) {
                if let file = fileToDiscard {
                    viewModel.discardFile(file)
                } else if showDiscardAllConfirmation {
                    viewModel.discardAll()
                }
                fileToDiscard = nil
                showDiscardAllConfirmation = false
            }
        } message: {
            if let file = fileToDiscard {
                Text("Are you sure you want to discard changes to '\(file)'? This cannot be undone.")
            } else {
                Text("Are you sure you want to discard all changes? This cannot be undone.")
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center, spacing: 16) {
            // Branch Indicator
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.accent)

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
                    HStack(spacing: 6) {
                        Text(branchLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
                .menuStyle(BorderlessButtonMenuStyle())

                // Copy branch name button
                Button(action: copyBranchName) {
                    Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(showCopiedFeedback ? Theme.success : Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Copy branch name")

                if let aheadBehind = viewModel.aheadBehindText {
                    Text(aheadBehind)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Actions: Pull & Push
            HStack(spacing: 8) {
                // Pull
                ActionButton(
                    icon: "arrow.down",
                    label: viewModel.isPulling ? "Pulling..." : "Pull",
                    isLoading: viewModel.isPulling,
                    isDisabled: !viewModel.canPull,
                    action: { viewModel.pull() }
                )

                // Push
                ActionButton(
                    icon: "arrow.up",
                    label: viewModel.isPushing ? "Pushing..." : "Push",
                    isLoading: viewModel.isPushing,
                    isDisabled: !viewModel.canPush,
                    action: { viewModel.push() }
                )
            }
        }
    }

    /// Copies the current branch name to clipboard
    private func copyBranchName() {
        guard let branch = viewModel.gitStatus?.currentBranch else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(branch, forType: .string)

        // Show feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopiedFeedback = true
        }

        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopiedFeedback = false
            }
        }
    }

    private var branchLabel: String {
        viewModel.gitStatus?.currentBranch ?? "..."
    }

    // MARK: - Changes List View

    private var changesListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Staged
                if !viewModel.stagedFiles.isEmpty {
                    FileGroupSection(
                        title: "STAGED CHANGES",
                        files: viewModel.stagedFiles,
                        accentColor: Theme.success,
                        onUnstage: { viewModel.unstageFile($0) },
                        onUnstageAll: { viewModel.unstageAll() }
                    )
                }

                // Modified
                if !viewModel.modifiedFiles.isEmpty {
                    FileGroupSection(
                        title: "CHANGES",
                        files: viewModel.modifiedFiles,
                        accentColor: Theme.warning,
                        onStage: { viewModel.stageFile($0) },
                        onDiscard: { fileToDiscard = $0 },
                        onStageAll: { viewModel.stageAll() },
                        onDiscardAll: { showDiscardAllConfirmation = true }
                    )
                }

                // Untracked
                if !viewModel.untrackedFiles.isEmpty {
                    FileGroupSection(
                        title: "UNTRACKED FILES",
                        files: viewModel.untrackedFiles,
                        accentColor: Theme.textTertiary,
                        onStage: { viewModel.stageFile($0) },
                        onStageAll: { viewModel.stageAll() }
                    )
                }

                Spacer(minLength: 20)
                
                // Commit Box
                CommitBox(
                    message: $viewModel.commitMessage,
                    isCommitting: viewModel.isCommitting,
                    canCommit: viewModel.canCommit,
                    commitAction: { viewModel.commit() }
                )
            }
            .padding(Theme.paddingLarge)
        }
    }

    // MARK: - Loading & Error States with Feedback

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)
                .controlSize(.large)
            Text("Checking status...")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(Theme.error)
                .opacity(0.8)
            
            VStack(spacing: 6) {
                Text("Something went wrong")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                
                Text(error.localizedDescription)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.success.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Theme.success)
            }
            
            Text("Everything is up to date.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Subcomponents

// MARK: - Subcomponents

struct ActionButton: View {
    let icon: String // System name
    let label: String // Used for tooltip
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold)) // Slightly larger icon
                }
            }
            .frame(width: 32, height: 32) // Fixed square size
            .foregroundColor(isDisabled ? Theme.textTertiary : (isHovering ? .white : Theme.textPrimary))
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDisabled ? Theme.surface : (isHovering ? Theme.accent : Theme.surfaceActive))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDisabled ? Theme.border.opacity(0.5) : (isHovering ? Theme.accent : Theme.border), lineWidth: 1)
            )
            .shadow(color: isHovering && !isDisabled ? Theme.accent.opacity(0.25) : Color.clear, radius: 8, x: 0, y: 4)
            .scaleEffect(isHovering && !isDisabled ? 1.05 : 1.0)
            .animation(.spring(response: 0.2), value: isHovering)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(label) // Tooltip
        .onHover { isHovering = $0 }
    }
}

struct FileGroupSection: View {
    let title: String
    let files: [GitFileChange]
    let accentColor: Color
    var onStage: ((String) -> Void)? = nil
    var onUnstage: ((String) -> Void)? = nil
    var onDiscard: ((String) -> Void)? = nil
    var onStageAll: (() -> Void)? = nil
    var onUnstageAll: (() -> Void)? = nil
    var onDiscardAll: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Theme.textTertiary)
                
                Text("\(files.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.surface)
                    .cornerRadius(4)
                
                Spacer()
                
                // Bulk Actions
                HStack(spacing: 4) {
                    if let onDiscardAll = onDiscardAll {
                        Button(action: onDiscardAll) {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textTertiary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .help("Discard all changes")
                    }
                    
                    if let onUnstageAll = onUnstageAll {
                        Button(action: onUnstageAll) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textTertiary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .help("Unstage all")
                    }
                    
                    if let onStageAll = onStageAll {
                        Button(action: onStageAll) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textTertiary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .help("Stage all")
                    }
                }
            }
            
            VStack(spacing: 1) { // Tighter spacing for card feel
                ForEach(files, id: \.path) { file in
                    FileRowItem(
                        file: file,
                        accentColor: accentColor,
                        onStage: onStage,
                        onUnstage: onUnstage,
                        onDiscard: onDiscard
                    )
                }
            }
            .background(Theme.surface)
            .cornerRadius(Theme.radius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .stroke(Theme.border.opacity(0.5), lineWidth: 1)
            )
        }
    }
}

struct FileRowItem: View {
    let file: GitFileChange
    let accentColor: Color
    let onStage: ((String) -> Void)?
    let onUnstage: ((String) -> Void)?
    let onDiscard: ((String) -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(statusColor)

            Text(file.path)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // Line stats (always visible if available)
            if let stats = file.lineStats, !stats.isEmpty {
                HStack(spacing: 4) {
                    if stats.added > 0 {
                        Text("+\(stats.added)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.success)
                    }
                    if stats.removed > 0 {
                        Text("-\(stats.removed)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.error)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.surface.opacity(0.5))
                .cornerRadius(4)
            }

            // Action Button (Visible on Hover)
            if isHovering {
                HStack(spacing: 8) {
                    if let onDiscard = onDiscard {
                        Button(action: { onDiscard(file.path) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textTertiary)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Discard changes")
                        .transition(.opacity)
                    }

                    Button(action: {
                        if let onStage = onStage { onStage(file.path) }
                        if let onUnstage = onUnstage { onUnstage(file.path) }
                    }) {
                        Image(systemName: onStage != nil ? "plus" : "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 24, height: 24)
                            .background(Theme.background)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(onStage != nil ? "Stage file" : "Unstage file")
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isHovering ? Theme.surfaceActive : Color.clear)
        .onHover { isHovering = $0 }
    }

    private var statusColor: Color {
        switch file.status {
        case .modified: return Theme.warning
        case .added: return Theme.success
        case .deleted: return Theme.error
        default: return Theme.textTertiary
        }
    }
}

struct CommitBox: View {
    @Binding var message: String
    let isCommitting: Bool
    let canCommit: Bool
    let commitAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("COMMIT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Theme.textTertiary)

                Spacer()

                Text("⌘↵")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textTertiary.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.surface)
                    .cornerRadius(4)
            }

            HStack(spacing: 12) {
                TextField("Summary", text: $message)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Theme.surface)
                    .cornerRadius(Theme.cornerRadiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .onSubmit {
                        if canCommit {
                            commitAction()
                        }
                    }

                Button(action: commitAction) {
                    HStack {
                        if isCommitting {
                            ProgressView().scaleEffect(0.5)
                        } else {
                            Text("Commit")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(canCommit ? Theme.accent : Theme.surfaceActive)
                    .cornerRadius(Theme.cornerRadiusMedium)
                }
                .buttonStyle(.plain)
                .disabled(!canCommit)
            }
        }
        .padding(Theme.paddingMedium)
        .background(Theme.surface)
        .cornerRadius(Theme.radius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .stroke(Theme.border.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    GitStatusView(project: Project(name: "Demo", path: "/"))
        .frame(width: 600, height: 500)
}
