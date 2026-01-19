import SwiftUI
import AppKit

/// Main view showing current branch, remote tracking status, and changed files
struct GitStatusView: View {
    let project: Project
    @FocusState.Binding var focusedArea: AppFocus?
    @EnvironmentObject var keyboardState: KeyboardState
    @StateObject private var viewModel = GitStatusViewModel()

    @State private var fileToDiscard: String?
    @State private var showDiscardAllConfirmation = false
    @State private var showCopiedFeedback = false
    @State private var isBranchHovered = false

    // File selection state
    @State private var selectedFileIndex: Int?
    @State private var selectedSection: FileSection = .changes
    @State private var keyboardMonitor: Any?

    enum FileSection: String, CaseIterable {
        case staged, changes, untracked
    }

    /// All files in display order for keyboard navigation
    private var allFiles: [(section: FileSection, file: GitFileChange)] {
        var files: [(FileSection, GitFileChange)] = []
        files += viewModel.stagedFiles.map { (.staged, $0) }
        files += viewModel.modifiedFiles.map { (.changes, $0) }
        files += viewModel.untrackedFiles.map { (.untracked, $0) }
        return files
    }

    /// Currently selected file
    private var selectedFile: GitFileChange? {
        guard let index = selectedFileIndex, index < allFiles.count else { return nil }
        return allFiles[index].file
    }

    /// Section of currently selected file
    private var selectedFileSection: FileSection? {
        guard let index = selectedFileIndex, index < allFiles.count else { return nil }
        return allFiles[index].section
    }

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
            setupKeyboardMonitor()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
            removeKeyboardMonitor()
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
        // Keyboard action handlers
        .onReceive(keyboardState.$triggerPush) { triggered in
            if triggered {
                keyboardState.triggerPush = false
                if viewModel.canPush { viewModel.push() }
            }
        }
        .onReceive(keyboardState.$triggerPull) { triggered in
            if triggered {
                keyboardState.triggerPull = false
                if viewModel.canPull { viewModel.pull() }
            }
        }
        .onReceive(keyboardState.$triggerCommit) { triggered in
            if triggered {
                keyboardState.triggerCommit = false
                if viewModel.canCommit { viewModel.commit() }
            }
        }
        .onReceive(keyboardState.$triggerStageAll) { triggered in
            if triggered {
                keyboardState.triggerStageAll = false
                viewModel.stageAll()
            }
        }
        .onReceive(keyboardState.$triggerUnstageAll) { triggered in
            if triggered {
                keyboardState.triggerUnstageAll = false
                viewModel.unstageAll()
            }
        }
        .onReceive(keyboardState.$triggerStageSelected) { triggered in
            if triggered {
                keyboardState.triggerStageSelected = false
                if let file = selectedFile, selectedFileSection != .staged {
                    viewModel.stageFile(file.path)
                    selectNextFile()
                }
            }
        }
        .onReceive(keyboardState.$triggerUnstageSelected) { triggered in
            if triggered {
                keyboardState.triggerUnstageSelected = false
                if let file = selectedFile, selectedFileSection == .staged {
                    viewModel.unstageFile(file.path)
                    selectNextFile()
                }
            }
        }
        .onReceive(keyboardState.$triggerDiscardSelected) { triggered in
            if triggered {
                keyboardState.triggerDiscardSelected = false
                if let file = selectedFile, selectedFileSection == .changes {
                    fileToDiscard = file.path
                }
            }
        }
        .onReceive(keyboardState.$triggerOpenTerminal) { triggered in
            if triggered {
                keyboardState.triggerOpenTerminal = false
                openInTerminal(project.path)
            }
        }
        .onReceive(keyboardState.$triggerOpenEditor) { triggered in
            if triggered {
                keyboardState.triggerOpenEditor = false
                openInEditor(project.path)
            }
        }
        .onReceive(keyboardState.$triggerRevealInFinder) { triggered in
            if triggered {
                keyboardState.triggerRevealInFinder = false
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path)
            }
        }
        .onReceive(keyboardState.$triggerCopyBranch) { triggered in
            if triggered {
                keyboardState.triggerCopyBranch = false
                copyBranchName()
            }
        }
        .onReceive(keyboardState.$triggerRefresh) { triggered in
            if triggered {
                keyboardState.triggerRefresh = false
                viewModel.refresh()
            }
        }
    }

    // MARK: - Keyboard Navigation

    private func setupKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            handleKeyEvent(event)
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Only handle when file list is focused
        guard focusedArea == .fileList else { return event }

        // Arrow keys: up = 126, down = 125, escape = 53, return = 36, space = 49
        switch event.keyCode {
        case 125: // Down arrow
            withAnimation(.easeOut(duration: Theme.animationFast)) {
                selectNextFile()
            }
            return nil
        case 126: // Up arrow
            withAnimation(.easeOut(duration: Theme.animationFast)) {
                selectPreviousFile()
            }
            return nil
        case 36, 49: // Return or Space - toggle stage/unstage
            if let file = selectedFile {
                if selectedFileSection == .staged {
                    viewModel.unstageFile(file.path)
                } else {
                    viewModel.stageFile(file.path)
                }
                return nil
            }
        case 53: // Escape - clear selection
            if selectedFileIndex != nil {
                selectedFileIndex = nil
                return nil
            }
        default:
            break
        }
        return event
    }

    private func selectNextFile() {
        guard !allFiles.isEmpty else { return }
        if let current = selectedFileIndex {
            selectedFileIndex = min(current + 1, allFiles.count - 1)
        } else {
            selectedFileIndex = 0
        }
    }

    private func selectPreviousFile() {
        guard !allFiles.isEmpty else { return }
        if let current = selectedFileIndex {
            selectedFileIndex = max(current - 1, 0)
        } else {
            selectedFileIndex = allFiles.count - 1
        }
    }

    // MARK: - External Actions

    private func openInTerminal(_ path: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    private func openInEditor(_ path: String) {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)

        let editors = [
            "/Applications/Cursor.app",
            "/Applications/Visual Studio Code.app",
            "/Applications/VSCodium.app",
            "/Applications/Sublime Text.app",
            "/Applications/Zed.app"
        ]

        for editorPath in editors {
            if fileManager.fileExists(atPath: editorPath) {
                NSWorkspace.shared.open(
                    [url],
                    withApplicationAt: URL(fileURLWithPath: editorPath),
                    configuration: NSWorkspace.OpenConfiguration()
                ) { _, _ in }
                return
            }
        }

        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
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
        }
        .buttonStyle(ScaleButtonStyle())
        .help("Copy branch name")
        .animation(.easeOut(duration: Theme.animationFast), value: showCopiedFeedback)
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

    // MARK: - Changes List

    private var changesListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space5) {
                // Keyboard shortcuts help
                KeyboardShortcutsHint()
                    .padding(.bottom, Theme.space2)

                // Staged
                if !viewModel.stagedFiles.isEmpty {
                    FileGroupSection(
                        title: "Staged",
                        count: viewModel.stagedFiles.count,
                        files: viewModel.stagedFiles,
                        accentColor: Theme.success,
                        selectedFilePath: selectedFile?.path,
                        onSelect: { selectFile($0, in: .staged) },
                        onUnstage: { viewModel.unstageFile($0) },
                        onUnstageAll: { viewModel.unstageAll() }
                    )
                }

                // Changes
                if !viewModel.modifiedFiles.isEmpty {
                    FileGroupSection(
                        title: "Changes",
                        count: viewModel.modifiedFiles.count,
                        files: viewModel.modifiedFiles,
                        accentColor: Theme.warning,
                        selectedFilePath: selectedFile?.path,
                        onSelect: { selectFile($0, in: .changes) },
                        onStage: { viewModel.stageFile($0) },
                        onDiscard: { fileToDiscard = $0 },
                        onStageAll: { viewModel.stageAll() },
                        onDiscardAll: { showDiscardAllConfirmation = true }
                    )
                }

                // Untracked
                if !viewModel.untrackedFiles.isEmpty {
                    FileGroupSection(
                        title: "Untracked",
                        count: viewModel.untrackedFiles.count,
                        files: viewModel.untrackedFiles,
                        accentColor: Theme.textTertiary,
                        selectedFilePath: selectedFile?.path,
                        onSelect: { selectFile($0, in: .untracked) },
                        onStage: { viewModel.stageFile($0) },
                        onStageAll: { viewModel.stageAll() }
                    )
                }

                // Commit box
                CommitBox(
                    message: $viewModel.commitMessage,
                    isCommitting: viewModel.isCommitting,
                    canCommit: viewModel.canCommit,
                    commitAction: { viewModel.commit() },
                    focusedArea: _focusedArea
                )
                .padding(.top, Theme.space2)
            }
            .padding(Theme.space6)
        }
        .focusable()
        .focused($focusedArea, equals: .fileList)
        .modifier(FocusEffectDisabledModifier())
        .onTapGesture {
            focusedArea = .fileList
        }
    }

    private func selectFile(_ path: String, in section: FileSection) {
        // Find the index in allFiles
        for (index, item) in allFiles.enumerated() {
            if item.file.path == path && item.section == section {
                selectedFileIndex = index
                focusedArea = .fileList
                break
            }
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
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(label)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
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
    var selectedFilePath: String? = nil
    var onSelect: ((String) -> Void)? = nil
    var onStage: ((String) -> Void)? = nil
    var onUnstage: ((String) -> Void)? = nil
    var onDiscard: ((String) -> Void)? = nil
    var onStageAll: (() -> Void)? = nil
    var onUnstageAll: (() -> Void)? = nil
    var onDiscardAll: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space3) {
            // Header with keyboard hints
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

                // Bulk actions with keyboard hints
                HStack(spacing: Theme.space1) {
                    if let onDiscardAll = onDiscardAll {
                        IconButton(icon: "trash", action: onDiscardAll, help: "Discard all")
                    }

                    if let onUnstageAll = onUnstageAll {
                        IconButton(icon: "minus", action: onUnstageAll, help: "Unstage all (⇧⌘U)")
                    }

                    if let onStageAll = onStageAll {
                        IconButton(icon: "plus", action: onStageAll, help: "Stage all (⇧⌘S)")
                    }
                }
            }

            // Files
            VStack(spacing: 0) {
                ForEach(files, id: \.path) { file in
                    FileRowItem(
                        file: file,
                        accentColor: accentColor,
                        isSelected: selectedFilePath == file.path,
                        onSelect: { onSelect?(file.path) },
                        onStage: onStage,
                        onUnstage: onUnstage,
                        onDiscard: onDiscard
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
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
    }
}

// MARK: - File Row Item

struct FileRowItem: View {
    let file: GitFileChange
    let accentColor: Color
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    let onStage: ((String) -> Void)?
    let onUnstage: ((String) -> Void)?
    let onDiscard: ((String) -> Void)?

    @State private var isHovered = false

    private var backgroundColor: Color {
        if isSelected { return Theme.accentMuted }
        if isHovered { return Theme.surfaceHover }
        return .clear
    }

    var body: some View {
        HStack(spacing: Theme.space3) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            // File path - takes full available width
            Text(file.path)
                .font(.system(size: Theme.fontBase, design: .monospaced))
                .foregroundColor(isSelected ? Theme.textPrimary : Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: Theme.space2)

            // Line stats - hide when hovered or selected to make room for action buttons
            if let stats = file.lineStats, !stats.isEmpty, !isHovered && !isSelected {
                lineStatsView(stats)
            }
        }
        .padding(.horizontal, Theme.space3)
        .padding(.vertical, Theme.space3)
        .background(backgroundColor)
        .overlay(alignment: .trailing) {
            // Action buttons overlay on hover with gradient fade
            if isHovered || isSelected {
                HStack(spacing: 0) {
                    // Gradient fade from transparent to hover background
                    LinearGradient(
                        colors: [backgroundColor.opacity(0), backgroundColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 32)

                    // Action buttons
                    HStack(spacing: Theme.space2) {
                        if let onDiscard = onDiscard {
                            FileActionButton(icon: "trash", hint: "⌘⌫") { onDiscard(file.path) }
                        }

                        FileActionButton(
                            icon: onStage != nil ? "plus" : "minus",
                            hint: onStage != nil ? "⌘S" : "⌘U"
                        ) {
                            if let onStage = onStage { onStage(file.path) }
                            if let onUnstage = onUnstage { onUnstage(file.path) }
                        }
                    }
                    .padding(.trailing, Theme.space3)
                    .padding(.vertical, Theme.space3)
                    .background(backgroundColor)
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect?()
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
        .animation(.easeOut(duration: Theme.animationFast), value: isSelected)
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
    var hint: String? = nil
    var action: () -> Void

    @State private var isHovered = false

    init(icon: String, hint: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.hint = hint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: Theme.fontSM, weight: .medium))

                if isHovered, let hint = hint {
                    Text(hint)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
            }
            .foregroundColor(isHovered ? Theme.textPrimary : Theme.textTertiary)
            .padding(.horizontal, isHovered && hint != nil ? 8 : 0)
            .frame(minWidth: 24, minHeight: 24)
            .background(isHovered ? Theme.surfaceActive : Theme.surface)
            .cornerRadius(Theme.radiusSmall)
        }
        .buttonStyle(.plain)
        .help(hint ?? "")
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
    }
}

// MARK: - Commit Box

struct CommitBox: View {
    @Binding var message: String
    let isCommitting: Bool
    let canCommit: Bool
    let commitAction: () -> Void
    @FocusState.Binding var focusedArea: AppFocus?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space3) {
            // Header
            HStack {
                Text("COMMIT")
                    .font(.system(size: Theme.fontXS, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(Theme.textMuted)

                Spacer()

                // Keyboard hints
                HStack(spacing: Theme.space2) {
                    KeyboardHintBadge("⌘↵")
                }
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
                            .stroke(focusedArea == .commitMessage ? Theme.borderFocus : Theme.border, lineWidth: 1)
                    )
                    .focused($focusedArea, equals: .commitMessage)
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
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!canCommit)
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

// MARK: - Keyboard Hints

struct KeyboardHintBadge: View {
    let shortcut: String

    init(_ shortcut: String) {
        self.shortcut = shortcut
    }

    var body: some View {
        Text(shortcut)
            .font(.system(size: Theme.fontXS, weight: .medium, design: .monospaced))
            .foregroundColor(Theme.textMuted)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.surface)
            .cornerRadius(4)
    }
}

struct KeyboardShortcutsHint: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space2) {
            Button(action: { withAnimation(.easeOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: Theme.space2) {
                    Image(systemName: "keyboard")
                        .font(.system(size: Theme.fontXS, weight: .medium))
                    Text("Keyboard Shortcuts")
                        .font(.system(size: Theme.fontXS, weight: .medium))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(Theme.textMuted)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: Theme.space1) {
                    shortcutRow("⌘S", "Stage selected file")
                    shortcutRow("⇧⌘S", "Stage all files")
                    shortcutRow("⌘U", "Unstage selected file")
                    shortcutRow("⇧⌘U", "Unstage all files")
                    shortcutRow("⌘⌫", "Discard selected file")
                    Divider().background(Theme.border)
                    shortcutRow("⌘↵", "Commit staged changes")
                    shortcutRow("⌘P", "Push to remote")
                    shortcutRow("⇧⌘P", "Pull from remote")
                    Divider().background(Theme.border)
                    shortcutRow("⌘F", "Search projects")
                    shortcutRow("⌘1", "Focus sidebar")
                    shortcutRow("⌘2", "Focus file list")
                    shortcutRow("↑↓", "Navigate files")
                    shortcutRow("↵ / Space", "Toggle stage/unstage")
                    shortcutRow("Esc", "Clear selection")
                    Divider().background(Theme.border)
                    shortcutRow("⌘T", "Open in Terminal")
                    shortcutRow("⌘E", "Open in Editor")
                    shortcutRow("⇧⌘O", "Reveal in Finder")
                    shortcutRow("⇧⌘C", "Copy branch name")
                    shortcutRow("⌘R", "Refresh status")
                }
                .padding(Theme.space3)
                .background(Theme.surface)
                .cornerRadius(Theme.radius)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Theme.space3)
        .background(Theme.surfaceElevated.opacity(0.5))
        .cornerRadius(Theme.radius)
    }

    private func shortcutRow(_ shortcut: String, _ description: String) -> some View {
        HStack {
            Text(shortcut)
                .font(.system(size: Theme.fontXS, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 60, alignment: .leading)
            Text(description)
                .font(.system(size: Theme.fontXS))
                .foregroundColor(Theme.textTertiary)
            Spacer()
        }
    }
}

struct GitStatusView_Previews: PreviewProvider {
    @FocusState static var focusedArea: AppFocus?

    static var previews: some View {
        GitStatusView(
            project: Project(name: "Demo", path: "/"),
            focusedArea: $focusedArea
        )
        .environmentObject(KeyboardState())
        .frame(width: 600, height: 500)
    }
}
