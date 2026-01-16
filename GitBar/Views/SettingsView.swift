import SwiftUI
import AppKit

/// Settings sheet view with app configuration options
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#2a2a2a"))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // Form content
            ScrollView {
                VStack(spacing: 0) {
                    // General Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GENERAL")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        VStack(spacing: 0) {
                            Toggle(isOn: $viewModel.launchAtLogin) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Launch at Login")
                                        .font(.system(size: 13))
                                    Text("Automatically start GitBar when you log in")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .background(Color(hex: "#1a1a1a"))
                    }

                    // Folders Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FOLDERS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Folder sources")
                                        .font(.system(size: 13))
                                    Text("Scan these folders for git repositories")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(action: addFolder) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("Add Folder")
                                            .font(.system(size: 13))
                                    }
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "#2a2a2a"))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)

                            if viewModel.repoFolders.isEmpty {
                                Divider()
                                    .padding(.leading, 20)

                                Text("No folders added")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                            } else {
                                Divider()
                                    .padding(.leading, 20)

                                VStack(spacing: 0) {
                                    ForEach(viewModel.repoFolders, id: \.self) { folderPath in
                                        HStack(spacing: 12) {
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
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color(hex: "#FF453A"))
                                            }
                                            .buttonStyle(.plain)
                                            .help("Remove folder")
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)

                                        if folderPath != viewModel.repoFolders.last {
                                            Divider()
                                                .padding(.leading, 20)
                                        }
                                    }
                                }
                            }
                        }
                        .background(Color(hex: "#1a1a1a"))
                    }

                    // Updates Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("UPDATES")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        VStack(spacing: 0) {
                            Toggle(isOn: $viewModel.checkForUpdatesAutomatically) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Check for updates automatically")
                                        .font(.system(size: 13))
                                    Text("Get notified when new versions are available")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)

                            Divider()
                                .padding(.leading, 20)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Check for updates")
                                        .font(.system(size: 13))
                                    if viewModel.isCheckingForUpdates {
                                        Text("Checking...")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    } else if let lastCheck = viewModel.lastUpdateCheck {
                                        Text("Last checked: \(formatDate(lastCheck))")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Button(action: { viewModel.checkForUpdates() }) {
                                    Text("Check Now")
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(hex: "#2a2a2a"))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isCheckingForUpdates)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .background(Color(hex: "#1a1a1a"))
                    }

                    // About Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ABOUT")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Version")
                                        .font(.system(size: 13))
                                    Text("GitBar \(viewModel.appVersion)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)

                            Divider()
                                .padding(.leading, 20)

                            Button(action: { viewModel.openGitHub() }) {
                                HStack {
                                    Text("View on GitHub")
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .background(Color(hex: "#1a1a1a"))
                    }

                    Spacer(minLength: 20)
                }
            }
        }
        .frame(width: 420, height: 420)
        .background(Color(hex: "#0d0d0d"))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        panel.message = "Choose a folder to scan for git repositories."

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.addRepoFolder(url.path)
        }
    }
}

#Preview {
    SettingsView()
}
