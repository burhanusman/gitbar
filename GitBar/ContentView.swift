import SwiftUI

struct ContentView: View {
    @StateObject private var projectListViewModel = ProjectListViewModel()
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with settings gear
            headerView

            Divider()

            // Main content
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var headerView: some View {
        HStack {
            Text("GitBar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(16)
    }
}

#Preview {
    ContentView()
}
