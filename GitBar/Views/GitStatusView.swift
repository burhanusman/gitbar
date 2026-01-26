import SwiftUI
import AppKit

/// Main view showing current branch, remote tracking status, and changed files
struct GitStatusView: View {
    let project: Project
    @StateObject private var viewModel = GitStatusViewModel()

    @State private var fileToDiscard: String?
    @State private var showDiscardAllConfirmation = false
    @State private var showCopiedFeedback = false
    @State private var isBranchHovered = false
    @State private var showNewBranchDialog = false
    @State private var newBranchName = ""
    @State private var selectedFileForDiff: GitFileChange?
    @State private var diffContent: String = ""
    @State private var isLoadingDiff = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
        .alert("Discard changes?", isPresented: Binding<Bool>(
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
                Text("Changes to '\(file)' will be permanently lost.")
            } else {
                Text("All uncommitted changes will be permanently lost.")
            }
        }
        .alert("New Branch", isPresented: $showNewBranchDialog) {
            TextField("Branch name", text: $newBranchName)
            Button("Cancel", role: .cancel) {
                newBranchName = ""
            }
            Button("Create") {
                let branchName = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !branchName.isEmpty {
                    viewModel.createAndCheckoutBranch(branchName)
                }
                newBranchName = ""
            }
            .disabled(newBranchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a name for the new branch. It will be created from the current branch.")
        }
        .sheet(item: Binding(
            get: { selectedFileForDiff },
            set: { selectedFileForDiff = $0 }
        )) { file in
            DiffViewer(filePath: file.path, diff: diffContent)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center, spacing: Theme.space4) {
            // Branch info - flexible width with hover area for copy button
            HStack(spacing: Theme.space2) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.accent)

                branchMenu

                // Copy button - fades in on hover
                copyBranchButton
                    .opacity(isBranchHovered || showCopiedFeedback ? 1 : 0)

                if let aheadBehind = viewModel.aheadBehindText {
                    aheadBehindBadge(aheadBehind)
                }
            }
            .onHover { isBranchHovered = $0 }

            Spacer()

            // Actions
            HStack(spacing: Theme.space2) {
                ActionButton(
                    icon: "arrow.down",
                    label: "Pull",
                    isLoading: viewModel.isPulling,
                    isDisabled: !viewModel.canPull,
                    action: { viewModel.pull() }
                )

                ActionButton(
                    icon: "arrow.up",
                    label: "Push",
                    isLoading: viewModel.isPushing,
                    isDisabled: !viewModel.canPush,
                    action: { viewModel.push() }
                )
            }
        }
        .animation(.easeOut(duration: Theme.animationFast), value: isBranchHovered)
        .animation(.easeOut(duration: Theme.animationFast), value: showCopiedFeedback)
    }

    private var branchMenu: some View {
        Menu {
            if viewModel.branches.isEmpty {
                Text("No local branches")
                    .foregroundColor(Theme.textTertiary)
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

            Divider()

            Button(action: { showNewBranchDialog = true }) {
                Label("New Branch...", systemImage: "plus")
            }
            .disabled(viewModel.isSwitchingBranch)
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.gitStatus?.currentBranch ?? "...")
                    .font(.system(size: Theme.fontLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .help(viewModel.gitStatus?.currentBranch ?? "")
    }

    private var copyBranchButton: some View {
        Button(action: copyBranchName) {
            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                .font(.system(size: Theme.fontSM, weight: .medium))
                .foregroundColor(showCopiedFeedback ? Theme.success : Theme.textMuted)
                .frame(width: 24, height: 24)
                .background(showCopiedFeedback ? Theme.successMuted : Theme.surface)
                .cornerRadius(Theme.radiusSmall)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .help("Copy branch name")
        .animation(.easeOut(duration: Theme.animationFast), value: showCopiedFeedback)
        .pointingHandCursor()
    }

    private func aheadBehindBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.fontXS, weight: .semibold, design: .monospaced))
            .foregroundColor(Theme.accent)
            .padding(.horizontal, Theme.space2)
            .padding(.vertical, Theme.space1)
            .background(Theme.accentMuted)
            .cornerRadius(Theme.radiusSmall)
    }

    private func copyBranchName() {
        guard let branch = viewModel.gitStatus?.currentBranch else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(branch, forType: .string)

        withAnimation(.easeOut(duration: Theme.animationFast)) {
            showCopiedFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: Theme.animationFast)) {
                showCopiedFeedback = false
            }
        }
    }

    private func showDiff(for file: GitFileChange) {
        guard !isLoadingDiff else { return }

        isLoadingDiff = true
        selectedFileForDiff = file
        diffContent = ""

        Task {
            do {
                let diff = try await viewModel.getDiff(
                    for: file.path,
                    staged: file.isStaged
                )
                await MainActor.run {
                    self.diffContent = diff
                    self.isLoadingDiff = false
                }
            } catch {
                await MainActor.run {
                    self.diffContent = "Error loading diff: \(error.localizedDescription)"
                    self.isLoadingDiff = false
                }
            }
        }
    }

    // MARK: - Changes List

    private var changesListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space5) {
                // Staged
                if !viewModel.stagedFiles.isEmpty {
                    FileGroupSection(
                        title: "Staged",
                        count: viewModel.stagedFiles.count,
                        files: viewModel.stagedFiles,
                        accentColor: Theme.success,
                        onUnstage: { viewModel.unstageFile($0) },
                        onUnstageAll: { viewModel.unstageAll() },
                        onFileClick: { showDiff(for: $0) }
                    )
                }

                // Changes
                if !viewModel.modifiedFiles.isEmpty {
                    FileGroupSection(
                        title: "Changes",
                        count: viewModel.modifiedFiles.count,
                        files: viewModel.modifiedFiles,
                        accentColor: Theme.warning,
                        onStage: { viewModel.stageFile($0) },
                        onDiscard: { fileToDiscard = $0 },
                        onStageAll: { viewModel.stageAll() },
                        onDiscardAll: { showDiscardAllConfirmation = true },
                        onFileClick: { showDiff(for: $0) }
                    )
                }

                // Untracked
                if !viewModel.untrackedFiles.isEmpty {
                    FileGroupSection(
                        title: "Untracked",
                        count: viewModel.untrackedFiles.count,
                        files: viewModel.untrackedFiles,
                        accentColor: Theme.textTertiary,
                        onStage: { viewModel.stageFile($0) },
                        onStageAll: { viewModel.stageAll() },
                        onFileClick: { showDiff(for: $0) }
                    )
                }

                // Commit box
                CommitBox(
                    message: $viewModel.commitMessage,
                    isCommitting: viewModel.isCommitting,
                    canCommit: viewModel.canCommit,
                    commitAction: { viewModel.commit() }
                )
                .padding(.top, Theme.space2)
            }
            .padding(Theme.space6)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: Theme.space4) {
            ProgressView()
                .scaleEffect(0.9)
            Text("Loading...")
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
                Text("Something went wrong")
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
                    .fill(Theme.successMuted)
                    .frame(width: 72, height: 72)

                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.success)
            }

            VStack(spacing: Theme.space2) {
                Text("All clear")
                    .font(.system(size: Theme.fontLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text("No uncommitted changes")
                    .font(.system(size: Theme.fontBase))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let label: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: Theme.fontBase, weight: .semibold))
                }
            }
            .frame(width: 32, height: 32)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(Theme.radius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(label)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
        .pointingHandCursor()
    }

    private var foregroundColor: Color {
        if isDisabled { return Theme.textMuted }
        if isHovered { return .white }
        return Theme.textSecondary
    }

    private var backgroundColor: Color {
        if isDisabled { return Theme.surface }
        if isHovered { return Theme.accent }
        return Theme.surface
    }

    private var borderColor: Color {
        if isDisabled { return Theme.borderSubtle }
        if isHovered { return Theme.accent }
        return Theme.border
    }
}

// MARK: - File Group Section

struct FileGroupSection: View {
    let title: String
    let count: Int
    let files: [GitFileChange]
    let accentColor: Color
    var onStage: ((String) -> Void)? = nil
    var onUnstage: ((String) -> Void)? = nil
    var onDiscard: ((String) -> Void)? = nil
    var onStageAll: (() -> Void)? = nil
    var onUnstageAll: (() -> Void)? = nil
    var onDiscardAll: (() -> Void)? = nil
    var onFileClick: ((GitFileChange) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space3) {
            // Header
            HStack(spacing: Theme.space2) {
                Text(title.uppercased())
                    .font(.system(size: Theme.fontXS, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(Theme.textMuted)

                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.15))
                    .cornerRadius(4)

                Spacer()

                // Bulk actions
                HStack(spacing: Theme.space1) {
                    if let onDiscardAll = onDiscardAll {
                        IconButton(icon: "trash", action: onDiscardAll, help: "Discard all")
                    }

                    if let onUnstageAll = onUnstageAll {
                        IconButton(icon: "minus", action: onUnstageAll, help: "Unstage all")
                    }

                    if let onStageAll = onStageAll {
                        IconButton(icon: "plus", action: onStageAll, help: "Stage all")
                    }
                }
            }

            // Files
            VStack(spacing: 0) {
                ForEach(files, id: \.path) { file in
                    FileRowItem(
                        file: file,
                        accentColor: accentColor,
                        onStage: onStage,
                        onUnstage: onUnstage,
                        onDiscard: onDiscard,
                        onClick: onFileClick
                    )

                    if file.path != files.last?.path {
                        Divider()
                            .background(Theme.border.opacity(0.5))
                    }
                }
            }
            .background(Theme.surface)
            .cornerRadius(Theme.radius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .stroke(Theme.borderSubtle, lineWidth: 1)
            )
        }
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let action: () -> Void
    let help: String

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Theme.fontXS, weight: .semibold))
                .foregroundColor(isHovered ? Theme.textSecondary : Theme.textMuted)
                .frame(width: 22, height: 22)
                .background(isHovered ? Theme.surfaceHover : .clear)
                .cornerRadius(Theme.radiusSmall)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
        .pointingHandCursor()
    }
}

// MARK: - File Row Item

struct FileRowItem: View {
    let file: GitFileChange
    let accentColor: Color
    let onStage: ((String) -> Void)?
    let onUnstage: ((String) -> Void)?
    let onDiscard: ((String) -> Void)?
    let onClick: ((GitFileChange) -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Theme.space3) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            // File path - takes full available width
            Text(file.path)
                .font(.system(size: Theme.fontBase, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: Theme.space2)

            // Line stats
            if let stats = file.lineStats, !stats.isEmpty {
                lineStatsView(stats)
            }
        }
        .padding(.horizontal, Theme.space3)
        .padding(.vertical, Theme.space3)
        .background(isHovered ? Theme.surfaceHover : .clear)
        .overlay(alignment: .trailing) {
            // Action buttons overlay on hover with gradient fade
            if isHovered {
                HStack(spacing: 0) {
                    // Gradient fade from transparent to hover background
                    LinearGradient(
                        colors: [Theme.surfaceHover.opacity(0), Theme.surfaceHover],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 32)

                    // Action buttons
                    HStack(spacing: Theme.space2) {
                        if let onDiscard = onDiscard {
                            FileActionButton(icon: "trash", action: { onDiscard(file.path) })
                        }

                        FileActionButton(
                            icon: onStage != nil ? "plus" : "minus",
                            action: {
                                if let onStage = onStage { onStage(file.path) }
                                if let onUnstage = onUnstage { onUnstage(file.path) }
                            }
                        )
                    }
                    .padding(.trailing, Theme.space3)
                    .padding(.vertical, Theme.space3)
                    .background(Theme.surfaceHover)
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
        .onTapGesture {
            onClick?(file)
        }
        .pointingHandCursor()
    }

    private func lineStatsView(_ stats: GitLineStats) -> some View {
        HStack(spacing: 3) {
            if stats.added > 0 {
                Text("+\(stats.added)")
                    .foregroundColor(Theme.success)
            }
            if stats.removed > 0 {
                Text("-\(stats.removed)")
                    .foregroundColor(Theme.error)
            }
        }
        .font(.system(size: Theme.fontXS, weight: .medium, design: .monospaced))
        .fixedSize()
        .padding(.horizontal, Theme.space2)
        .padding(.vertical, 3)
        .background(Theme.background)
        .cornerRadius(4)
    }

    private var statusColor: Color {
        switch file.status {
        case .modified: return Theme.warning
        case .added: return Theme.success
        case .deleted: return Theme.error
        default: return Theme.textMuted
        }
    }
}

// MARK: - File Action Button

struct FileActionButton: View {
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Theme.fontSM, weight: .medium))
                .foregroundColor(isHovered ? Theme.textPrimary : Theme.textTertiary)
                .frame(width: 24, height: 24)
                .background(isHovered ? Theme.surfaceActive : Theme.surface)
                .cornerRadius(Theme.radiusSmall)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
        .pointingHandCursor()
    }
}

// MARK: - Commit Box

struct CommitBox: View {
    @Binding var message: String
    let isCommitting: Bool
    let canCommit: Bool
    let commitAction: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space3) {
            // Header
            HStack {
                Text("COMMIT")
                    .font(.system(size: Theme.fontXS, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(Theme.textMuted)

                Spacer()

                // Keyboard hint
                Text("↵")
                    .font(.system(size: Theme.fontXS, weight: .medium))
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.surface)
                    .cornerRadius(4)
            }

            // Input row
            HStack(spacing: Theme.space3) {
                TextField("Commit message...", text: $message)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.fontBase))
                    .padding(.horizontal, Theme.space3)
                    .padding(.vertical, Theme.space3)
                    .background(Theme.surface)
                    .cornerRadius(Theme.radius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radius)
                            .stroke(isFocused ? Theme.borderFocus : Theme.border, lineWidth: 1)
                    )
                    .focused($isFocused)
                    .onSubmit {
                        if canCommit { commitAction() }
                    }

                Button(action: commitAction) {
                    Group {
                        if isCommitting {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            Text("Commit")
                                .font(.system(size: Theme.fontBase, weight: .semibold))
                        }
                    }
                    .frame(width: 70, height: 36)
                    .foregroundColor(canCommit ? .white : Theme.textMuted)
                    .background(canCommit ? Theme.accent : Theme.surface)
                    .cornerRadius(Theme.radius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radius)
                            .stroke(canCommit ? Theme.accent : Theme.border, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!canCommit)
                .pointingHandCursor()
            }
        }
        .padding(Theme.space4)
        .background(Theme.surfaceElevated)
        .cornerRadius(Theme.radiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

#Preview {
    GitStatusView(project: Project(name: "Demo", path: "/"))
        .frame(width: 600, height: 500)
}
