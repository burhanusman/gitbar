import SwiftUI
import AppKit

/// Settings popover view with app configuration options
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Launch at Login toggle
            Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
                .font(.system(size: 13))
                .toggleStyle(.switch)

            Divider()

            // Additional repo folders
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Folders")
                        .font(.system(size: 13, weight: .medium))

                    Spacer()

                    Button(action: addFolder) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add a folder to scan for git repos")
                }

                if viewModel.repoFolders.isEmpty {
                    Text("No folders added")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.repoFolders, id: \.self) { folderPath in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(URL(fileURLWithPath: folderPath).lastPathComponent)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Text(folderPath)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                Button(action: { viewModel.removeRepoFolder(folderPath) }) {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Remove folder")
                            }
                            .padding(8)
                            .background(Color(hex: "#2a2a2a"))
                            .cornerRadius(6)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 340, height: 340)
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.addRepoFolder(url.path)
        }
    }
}

#Preview {
    SettingsView()
}
