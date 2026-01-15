import SwiftUI

/// Sidebar view displaying the list of projects
struct ProjectListView: View {
    @ObservedObject var viewModel: ProjectListViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(viewModel.projects) { project in
                    ProjectRow(
                        project: project,
                        isSelected: viewModel.selectedProject?.id == project.id
                    )
                    .onTapGesture {
                        viewModel.selectProject(project)
                    }
                }
            }
            .padding(.vertical, 4)
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

    var body: some View {
        HStack(spacing: 8) {
            // Uncommitted changes indicator
            Circle()
                .fill(project.hasUncommittedChanges ? Color.orange : Color.clear)
                .frame(width: 8, height: 8)

            Text(project.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProjectListView(viewModel: ProjectListViewModel())
        .frame(width: 200, height: 400)
}
