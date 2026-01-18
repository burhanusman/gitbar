import SwiftUI
import AppKit

/// Sidebar view displaying the list of projects
struct ProjectListView: View {
    @ObservedObject var viewModel: ProjectListViewModel
    @State private var hoveredProjectId: String?
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var keyboardMonitor: Any?

    /// Filtered projects based on search text
    private var filteredSections: [ProjectSection] {
        guard !searchText.isEmpty else { return viewModel.sections }

        return viewModel.sections.compactMap { section in
            let filtered = section.projects.filter { project in
                project.name.localizedCaseInsensitiveContains(searchText)
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
            }
            .padding(.horizontal, Theme.space4)
            .padding(.vertical, Theme.space2)

            // Project list
            ScrollView {
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
                    ForEach(section.wrappedValue.projects) { project in
                        projectRow(for: project)
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
                ForEach(section.projects) { project in
                    projectRow(for: project)
                }
            }
        }
    }

    // MARK: - Project Row

    @ViewBuilder
    private func projectRow(for project: Project) -> some View {
        ProjectRow(
            project: project,
            isSelected: viewModel.selectedProject?.id == project.id,
            isHovered: hoveredProjectId == project.id
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

    var body: some View {
        HStack(spacing: Theme.space3) {
            // Status indicator
            statusIndicator

            // Project name
            Text(project.name)
                .font(.system(size: Theme.fontBase, weight: isSelected ? .medium : .regular))
                .foregroundColor(textColor)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, Theme.space3)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .cornerRadius(Theme.radius)
        .shadow(
            color: isSelected ? Theme.accent.opacity(0.12) : .clear,
            radius: isSelected ? 8 : 0,
            x: 0,
            y: isSelected ? 2 : 0
        )
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
