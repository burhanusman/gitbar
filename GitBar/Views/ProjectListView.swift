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
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Add")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#1a1a1a"))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Add folder source")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach($viewModel.sections) { section in
                        DisclosureGroup(isExpanded: section.isExpanded) {
                            VStack(spacing: 4) {
                                if section.wrappedValue.projects.isEmpty {
                                    Text("No repos found")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 8)
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
                            .padding(.top, 4)
                        } label: {
                            HStack(spacing: 4) {
                                Text(section.wrappedValue.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.leading, 28)
                            .padding(.trailing, 8)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
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
    @State private var hoverScale: CGFloat = 1.0
    @State private var indicatorPulse: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 10) {
            // Uncommitted changes indicator with pulse
            ZStack {
                if project.hasUncommittedChanges {
                    Circle()
                        .fill(Color(hex: "#0A84FF").opacity(0.3))
                        .frame(width: 6, height: 6)
                        .scaleEffect(indicatorPulse)
                        .opacity(2.0 - indicatorPulse)
                }

                Circle()
                    .fill(project.hasUncommittedChanges ? Color(hex: "#0A84FF") : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 8, alignment: .center)
            .onAppear {
                if project.hasUncommittedChanges {
                    withAnimation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                    ) {
                        indicatorPulse = 2.0
                    }
                }
            }

            Text(project.name)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .cornerRadius(6)
        .scaleEffect(hoverScale)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
                hoverScale = hovering && !isSelected ? 1.02 : 1.0
            }
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
