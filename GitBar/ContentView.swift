import SwiftUI

struct ContentView: View {
    @StateObject private var projectListViewModel = ProjectListViewModel()

    var body: some View {
        NavigationSplitView {
            ProjectListView(viewModel: projectListViewModel)
                .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
        } detail: {
            if let selectedProject = projectListViewModel.selectedProject {
                ProjectDetailView(project: selectedProject)
            } else {
                VStack {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Select a project")
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Placeholder detail view for selected project
struct ProjectDetailView: View {
    let project: Project

    var body: some View {
        VStack(spacing: 12) {
            Text(project.name)
                .font(.headline)
            Text(project.path)
                .font(.caption)
                .foregroundColor(.secondary)
            if project.hasUncommittedChanges {
                HStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Has uncommitted changes")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
