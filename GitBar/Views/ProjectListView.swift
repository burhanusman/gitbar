import SwiftUI
import AppKit

/// Sidebar view displaying the list of projects
struct ProjectListView: View {
    @ObservedObject var viewModel: ProjectListViewModel
    @State private var hoveredProjectId: String?
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var keyboardMonitor: Any?
    @State private var isSortButtonHovered: Bool = false

    /// Filtered projects based on search text (also matches worktree branch names)
    private var filteredSections: [ProjectSection] {
        guard !searchText.isEmpty else { return viewModel.sections }

        return viewModel.sections.compactMap { section in
            let filtered = section.projects.filter { project in
                if project.name.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                // Also match worktree branch names
                return project.worktrees.contains { wt in
                    wt.branch?.localizedCaseInsensitiveContains(searchText) == true
                }
            }
            guard !filtered.isEmpty else { return nil }
            return ProjectSection(
                id: section.id,
                title: section.title,
                isExpanded: true,
                projects: filtered
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            searchField
                .padding(.horizontal, Theme.space3)
                .padding(.top, Theme.space3)
                .padding(.bottom, Theme.space2)

            // Header with project count
            HStack {
                Text("PROJECTS")
                    .font(.system(size: Theme.fontXS, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(Theme.textMuted)

                Spacer()

                // Sort toggle button
                SortToggleButton(
                    sortMode: viewModel.sortMode,
                    isHovered: isSortButtonHovered,
                    action: { viewModel.toggleSortMode() }
                )
                .onHover { isHovered in
                    withAnimation(.easeOut(duration: Theme.animationFast)) {
                        isSortButtonHovered = isHovered
                    }
                }

                Button(action: addFolderSource) {
                    Image(systemName: "plus")
                        .font(.system(size: Theme.fontXS, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                        .frame(width: 22, height: 22)
                        .background(Theme.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .help("Add folder source")
                .pointingHandCursor()
            }
            .padding(.horizontal, Theme.space4)
            .padding(.vertical, Theme.space2)

            // Project list
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: Theme.space1) {
                    if searchText.isEmpty {
                        normalSectionsView
                    } else {
                        filteredResultsView
                    }
                }
                .padding(.horizontal, Theme.space3)
                .padding(.vertical, Theme.space2)
            }
            .background(Theme.sidebarBackground)
            .onAppear {
                viewModel.loadProjects()
                viewModel.startAutoRefresh()
                setupKeyboardMonitor()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
                removeKeyboardMonitor()
            }
        }
    }

    // MARK: - Keyboard Navigation

    private func setupKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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
        // Only handle if not in a text field (other than our search field)
        // Arrow keys: up = 126, down = 125
        switch event.keyCode {
        case 125: // Down arrow
            withAnimation(.easeOut(duration: Theme.animationFast)) {
                let sections = searchText.isEmpty ? nil : filteredSections
                viewModel.selectNextProject(filteredSections: sections)
            }
            return nil // Consume the event
        case 126: // Up arrow
            withAnimation(.easeOut(duration: Theme.animationFast)) {
                let sections = searchText.isEmpty ? nil : filteredSections
                viewModel.selectPreviousProject(filteredSections: sections)
            }
            return nil // Consume the event
        default:
            return event // Pass through other events
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: Theme.space2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Theme.fontSM, weight: .medium))
                .foregroundColor(isSearchFocused ? Theme.accent : Theme.textTertiary)

            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: Theme.fontBase))
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button(action: { withAnimation(.easeOut(duration: 0.15)) { searchText = "" } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Theme.fontSM))
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
                .pointingHandCursor()
            }
        }
        .padding(.horizontal, Theme.space3)
        .padding(.vertical, Theme.space2)
        .background(Theme.surface)
        .cornerRadius(Theme.radius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .stroke(isSearchFocused ? Theme.borderFocus : Theme.borderSubtle, lineWidth: 1)
        )
        .animation(.easeOut(duration: Theme.animationFast), value: isSearchFocused)
    }

    // MARK: - Normal Sections View

    @ViewBuilder
    private var normalSectionsView: some View {
        ForEach($viewModel.sections) { section in
            DisclosureGroup(isExpanded: section.isExpanded) {
                if section.wrappedValue.projects.isEmpty {
                    emptySourceView
                } else {
                    let projects = section.wrappedValue.projects
                    ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                        let nextBarId = index < projects.count - 1 ? projects[index + 1].id : nil
                        projectRow(for: project, nextBarId: nextBarId)
                    }
                }
            } label: {
                sectionLabel(section.wrappedValue)
            }
        }
    }

    private func sectionLabel(_ section: ProjectSection) -> some View {
        HStack(spacing: Theme.space2) {
            Text(section.title.uppercased())
                .font(.system(size: Theme.fontXS, weight: .medium))
                .tracking(0.5)
                .foregroundColor(Theme.textMuted)

            Text("\(section.projects.count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textMuted)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Theme.surface)
                .cornerRadius(4)

            Spacer()
        }
        .padding(.vertical, Theme.space1)
        .contentShape(Rectangle())
    }

    private var emptySourceView: some View {
        Text("No repositories")
            .font(.system(size: Theme.fontSM))
            .foregroundColor(Theme.textMuted)
            .padding(.leading, Theme.space3)
            .padding(.vertical, Theme.space2)
    }

    // MARK: - Filtered Results View

    @ViewBuilder
    private var filteredResultsView: some View {
        if filteredSections.isEmpty {
            VStack(spacing: Theme.space3) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(Theme.textMuted)

                Text("No results")
                    .font(.system(size: Theme.fontBase, weight: .medium))
                    .foregroundColor(Theme.textTertiary)

                Text("Try a different search term")
                    .font(.system(size: Theme.fontSM))
                    .foregroundColor(Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.space8)
        } else {
            ForEach(filteredSections) { section in
                let projects = section.projects
                ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                    let nextBarId = index < projects.count - 1 ? projects[index + 1].id : nil
                    projectRow(for: project, nextBarId: nextBarId)
                }
            }
        }
    }

    // MARK: - Project Row

    @ViewBuilder
    private func projectRow(for project: Project, nextBarId: String? = nil) -> some View {
        VStack(spacing: 0) {
            ProjectRow(
                project: project,
                isSelected: viewModel.selectedProject?.id == project.id,
                isHovered: hoveredProjectId == project.id,
                isExpanded: viewModel.expandedWorktreeProjects.contains(project.id),
                nextBarId: nextBarId,
                onToggleExpand: project.hasWorktrees ? {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.toggleWorktreeExpansion(for: project.id)
                    }
                } : nil
            )
            .onTapGesture {
                withAnimation(.easeOut(duration: Theme.animationBase)) {
                    viewModel.selectProject(project)
                }
            }
            .onHover { isHovering in
                withAnimation(.easeOut(duration: Theme.animationFast)) {
                    hoveredProjectId = isHovering ? project.id : nil
                }
            }
            .contextMenu {
                Button(action: { openInTerminal(project.path) }) {
                    Label("Open in Terminal", systemImage: "terminal")
                }

                Button(action: { openInEditor(project.path) }) {
                    Label("Open in Editor", systemImage: "curlybraces")
                }

                Divider()

                Button(action: { revealInFinder(project.path) }) {
                    Label("Reveal in Finder", systemImage: "folder")
                }

                Button(action: { copyPath(project.path) }) {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }
            }

            // Expanded worktree sub-rows
            if project.hasWorktrees && viewModel.expandedWorktreeProjects.contains(project.id) {
                VStack(spacing: 0) {
                    ForEach(project.worktrees) { worktree in
                        WorktreeRow(
                            worktree: worktree,
                            isSelected: viewModel.selectedWorktreePath == worktree.path,
                            isLast: worktree.id == project.worktrees.last?.id
                        )
                        .onTapGesture {
                            withAnimation(.easeOut(duration: Theme.animationBase)) {
                                viewModel.selectWorktree(worktree, in: project)
                            }
                        }
                        .contextMenu {
                            Button(action: { openInTerminal(worktree.path) }) {
                                Label("Open in Terminal", systemImage: "terminal")
                            }

                            Button(action: { openInEditor(worktree.path) }) {
                                Label("Open in Editor", systemImage: "curlybraces")
                            }

                            Divider()

                            Button(action: { revealInFinder(worktree.path) }) {
                                Label("Reveal in Finder", systemImage: "folder")
                            }

                            Button(action: { copyPath(worktree.path) }) {
                                Label("Copy Path", systemImage: "doc.on.doc")
                            }

                            if !worktree.isMain {
                                Divider()
                                Button(role: .destructive, action: {
                                    removeWorktree(worktree, from: project)
                                }) {
                                    Label("Remove Worktree", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func removeWorktree(_ worktree: WorktreeInfo, from project: Project) {
        Task {
            let gitService = GitService()
            do {
                try await gitService.removeWorktree(at: project.path, worktreePath: worktree.path)
                viewModel.refreshStatus()
            } catch {
                // Silently fail - could add error display later
            }
        }
    }

    // MARK: - Actions

    private func addFolderSource() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        panel.message = "Choose a folder containing git repositories"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            SettingsService.shared.addRepoFolder(url.path)
        }
    }

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

    private func revealInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    private func copyPath(_ path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: Project
    let isSelected: Bool
    let isHovered: Bool
    var isExpanded: Bool = false
    var nextBarId: String? = nil
    var onToggleExpand: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space2) {
            HStack(spacing: Theme.space3) {
                // Status indicator
                statusIndicator

                // Project name
                Text(project.name)
                    .font(.system(size: Theme.fontBase, weight: isSelected ? .medium : .regular))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                Spacer()

                // Worktree count badge + chevron (only when project has worktrees)
                if project.hasWorktrees {
                    worktreeBadge
                }
            }

            // Momentum bar - commit activity visualization
            HStack {
                Spacer()
                MomentumBar(activity: project.commitActivity, barId: project.id, nextBarId: nextBarId)
            }
        }
        .padding(.horizontal, Theme.space3)
        .padding(.vertical, Theme.space2)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(backgroundColor)
                .shadow(
                    color: isSelected ? Theme.accent.opacity(0.12) : .clear,
                    radius: isSelected ? 8 : 0,
                    x: 0,
                    y: isSelected ? 2 : 0
                )
        )
        .pointingHandCursor()
    }

    @ViewBuilder
    private var worktreeBadge: some View {
        Button(action: { onToggleExpand?() }) {
            HStack(spacing: 3) {
                Text("\(project.worktrees.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textMuted)

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.surface)
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }

    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: indicatorSize, height: indicatorSize)
            .shadow(
                color: project.hasUncommittedChanges ? Theme.accent.opacity(0.4) : .clear,
                radius: project.hasUncommittedChanges ? 4 : 0
            )
    }

    private var indicatorColor: Color {
        project.hasUncommittedChanges ? Theme.accent : Theme.textMuted.opacity(0.4)
    }

    private var indicatorSize: CGFloat {
        project.hasUncommittedChanges ? 8 : 6
    }

    private var textColor: Color {
        if isSelected { return Theme.textPrimary }
        if isHovered { return Theme.textPrimary }
        return Theme.textSecondary
    }

    private var backgroundColor: Color {
        if isSelected { return Theme.accentMuted }
        if isHovered { return Theme.surfaceHover }
        return .clear
    }
}

// MARK: - Worktree Row

struct WorktreeRow: View {
    let worktree: WorktreeInfo
    let isSelected: Bool
    var isLast: Bool = false

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Theme.space2) {
            // Connector line
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.borderSubtle)
                    .frame(width: 1)
                if isLast {
                    Spacer()
                }
            }
            .frame(width: 1, height: isLast ? 12 : nil)
            .padding(.leading, Theme.space4)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.borderSubtle)
                    .frame(width: 8, height: 1)
            }

            // Status dot
            Circle()
                .fill(worktree.hasUncommittedChanges ? Theme.accent : Theme.textMuted.opacity(0.4))
                .frame(width: 6, height: 6)

            // Branch name
            Text(worktree.branch ?? "detached")
                .font(.system(size: Theme.fontSM, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(1)

            // Agent label pill
            if let label = worktree.agentLabel {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.purple)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.purple.opacity(0.15))
                    .cornerRadius(4)
            }

            // Primary badge for main worktree
            if worktree.isMain {
                Text("primary")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.surface)
                    .cornerRadius(4)
            }

            Spacer()
        }
        .padding(.vertical, Theme.space1)
        .padding(.trailing, Theme.space3)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .fill(isSelected ? Theme.accentMuted : (isHovered ? Theme.surfaceHover : .clear))
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
        .pointingHandCursor()
    }
}

// MARK: - Sort Toggle Button

struct SortToggleButton: View {
    let sortMode: ProjectSortMode
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                // Main icon
                Group {
                    if sortMode == .alphabetical {
                        Text("A")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    } else {
                        Image(systemName: "clock")
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
                .foregroundColor(isHovered ? Theme.textSecondary : Theme.textTertiary)

                // Arrow indicator
                Image(systemName: sortMode == .alphabetical ? "chevron.down" : "chevron.up")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(isHovered ? Theme.textSecondary : Theme.textTertiary)
            }
            .frame(width: 26, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Theme.surfaceHover : Theme.surface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .help(sortMode == .alphabetical ? "Sort by recent activity" : "Sort alphabetically")
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: sortMode)
        .pointingHandCursor()
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ProjectListView(viewModel: ProjectListViewModel())
        .frame(width: 240, height: 500)
        .background(Theme.sidebarBackground)
}
