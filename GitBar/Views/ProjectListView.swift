import SwiftUI
import AppKit

/// Sidebar view displaying the list of projects
struct ProjectListView: View {
    @ObservedObject var viewModel: ProjectListViewModel
    @State private var hoveredProjectId: String?

    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.top, Theme.paddingMedium)
            .padding(.bottom, Theme.paddingSmall)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
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
                    .fill(Theme.accent)
                    .frame(width: 6, height: 6)
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

            // Source Badge
            if project.source != .folder {
                Text(project.source.rawValue.prefix(1).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(badgeColor)
                    .frame(width: 16, height: 16)
                    .background(badgeColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
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

    private var badgeColor: Color {
        switch project.source {
        case .claude: return Theme.ai
        case .codex: return Color.purple
        case .folder: return Theme.textTertiary
        }
    }
}

#Preview {
    ProjectListView(viewModel: ProjectListViewModel())
        .frame(width: 240, height: 500)
        .background(Theme.sidebarBackground)
}
