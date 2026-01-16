import SwiftUI
import AppKit

/// Sidebar view displaying the list of projects
struct ProjectListView: View {
    @ObservedObject var viewModel: ProjectListViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: addFolderSource) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Add")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#1a1a1a"))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Add folder source")
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach($viewModel.sections) { section in
                        DisclosureGroup(isExpanded: section.isExpanded) {
                            VStack(spacing: 8) {
                                if section.wrappedValue.projects.isEmpty {
                                    Text("No repos found")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                } else {
                                    ForEach(section.wrappedValue.projects) { project in
                                        ProjectRow(
                                            project: project,
                                            isSelected: viewModel.selectedProject?.id == project.id
                                        )
                                        .onTapGesture {
                                            viewModel.selectProject(project)
                                        }
                                    }
                                }
                            }
                            .padding(.leading, 8)
                            .padding(.top, 4)
                        } label: {
                            HStack(spacing: 4) {
                                Text(section.wrappedValue.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(minWidth: 150)
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
}

/// Individual row for a project in the sidebar
struct ProjectRow: View {
    let project: Project
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Uncommitted changes indicator
            Circle()
                .fill(project.hasUncommittedChanges ? Color(hex: "#0A84FF") : Color.clear)
                .frame(width: 6, height: 6)

            Text(project.name)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // Source badge for Claude/Codex projects
            if project.source != .folder {
                Text(project.source.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(badgeForegroundColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeBackgroundColor)
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .cornerRadius(6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color(hex: "#2a2a2a")
        } else if isHovering {
            return Color(hex: "#1a1a1a").opacity(0.5)
        } else {
            return Color.clear
        }
    }

    private var badgeBackgroundColor: Color {
        switch project.source {
        case .claude:
            return Color(hex: "#0A84FF").opacity(0.15)
        case .codex:
            return Color(hex: "#BF5AF2").opacity(0.15)
        case .folder:
            return Color.clear
        }
    }

    private var badgeForegroundColor: Color {
        switch project.source {
        case .claude:
            return Color(hex: "#0A84FF")
        case .codex:
            return Color(hex: "#BF5AF2")
        case .folder:
            return Color.secondary
        }
    }
}

#Preview {
    ProjectListView(viewModel: ProjectListViewModel())
        .frame(width: 200, height: 400)
}
