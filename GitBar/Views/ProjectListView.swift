import SwiftUI
import AppKit

/// Sidebar view displaying the list of projects
struct ProjectListView: View {
    @ObservedObject var viewModel: ProjectListViewModel
    @State private var hoveredProjectId: String?
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

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
                isExpanded: true, // Always expanded when searching
                projects: filtered
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)

                TextField("Search projects...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSearchFocused ? Theme.accent.opacity(0.5) : Theme.border.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Header
            HStack {
                Text("PROJECTS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Theme.textTertiary)

                Spacer()

                Button(action: addFolderSource) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(Theme.surface)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Theme.border.opacity(0.5), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Add folder source")
            }
            .padding(.horizontal, Theme.padding)
            .padding(.top, Theme.paddingSmall)
            .padding(.bottom, Theme.paddingSmall)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if searchText.isEmpty {
                        // Normal view with collapsible sections
                        ForEach($viewModel.sections) { section in
                            DisclosureGroup(isExpanded: section.isExpanded) {
                                if section.wrappedValue.projects.isEmpty {
                                    Text("No repos found")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textTertiary)
                                        .padding(.leading, 12)
                                        .padding(.vertical, 8)
                                } else {
                                    ForEach(section.wrappedValue.projects) { project in
                                        projectRow(for: project)
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(section.wrappedValue.title.uppercased())
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(0.5)
                                        .foregroundColor(Theme.textTertiary)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation {
                                        section.wrappedValue.isExpanded.toggle()
                                    }
                                }
                            }
                        }
                    } else {
                        // Filtered view - flat list when searching
                        if filteredSections.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 20))
                                    .foregroundColor(Theme.textTertiary)
                                Text("No projects found")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(filteredSections) { section in
                                ForEach(section.projects) { project in
                                    projectRow(for: project)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Theme.sidebarBackground)
            .onAppear {
                viewModel.loadProjects()
                viewModel.startAutoRefresh()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
        }
    }

    private func addFolderSource() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        panel.message = "Choose a folder to scan for git repositories."

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            SettingsService.shared.addRepoFolder(url.path)
        }
    }

    /// Creates a project row with context menu
    @ViewBuilder
    private func projectRow(for project: Project) -> some View {
        ProjectRow(
            project: project,
            isSelected: viewModel.selectedProject?.id == project.id,
            isHovered: hoveredProjectId == project.id
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectProject(project)
            }
        }
        .onHover { isHovering in
            if isHovering {
                hoveredProjectId = project.id
                NSCursor.pointingHand.push()
            } else {
                if hoveredProjectId == project.id {
                    hoveredProjectId = nil
                }
                NSCursor.pop()
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

    /// Opens the project folder in Terminal
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

    /// Opens the project folder in the default code editor (VS Code, Cursor, or falls back to Finder)
    private func openInEditor(_ path: String) {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)

        // Try common code editors in order of preference
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

        // Fallback: open in Finder
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    /// Reveals the project in Finder
    private func revealInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    /// Copies the project path to clipboard
    private func copyPath(_ path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }
}

/// Individual row for a project in the sidebar
struct ProjectRow: View {
    let project: Project
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator (Dot)
            if project.hasUncommittedChanges {
                Circle()
                // Use a slightly larger, cleaner dot
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: Theme.accent.opacity(0.4), radius: 3)
            } else {
                Circle()
                    .fill(Theme.textTertiary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }

            // Project Name
            Text(project.name)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .white : (isHovered ? Theme.textPrimary : Theme.textSecondary))
                .lineLimit(1)

            Spacer()
            
            // Removed Source Badge "C" as per request
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .scaleEffect(isHovered && !isSelected ? 1.01 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        // Glow effect for selected
        .shadow(color: isSelected ? Theme.accent.opacity(0.15) : Color.clear, radius: 8, x: 0, y: 4)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Theme.accent.opacity(0.15) // Subtle tinted background for selected
        } else if isHovered {
            return Theme.surfaceHover
        } else {
            return Color.clear
        }
    }
}

#Preview {
    ProjectListView(viewModel: ProjectListViewModel())
        .frame(width: 240, height: 500)
        .background(Theme.sidebarBackground)
}
