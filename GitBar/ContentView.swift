import SwiftUI

struct ContentView: View {
    @StateObject private var projectListViewModel = ProjectListViewModel()

    var body: some View {
        NavigationSplitView {
            ProjectListView(viewModel: projectListViewModel)
                .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
        } detail: {
            if let selectedProject = projectListViewModel.selectedProject {
                GitStatusView(project: selectedProject)
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

#Preview {
    ContentView()
}
