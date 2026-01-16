import SwiftUI

/// Sidebar view displaying the list of projects
struct ProjectListView: View {
    @ObservedObject var viewModel: ProjectListViewModel

    var body: some View {
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
                        Text(section.wrappedValue.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
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
}

#Preview {
    ProjectListView(viewModel: ProjectListViewModel())
        .frame(width: 200, height: 400)
}
