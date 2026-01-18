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
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.accent)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Theme.surface)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Theme.border),
                alignment: .bottom
            )

            // Form content
            ScrollView {
                VStack(spacing: 24) {
                    // General Section
                    sectionContainer(title: "GENERAL") {
                        VStack(spacing: 0) {
                            Toggle(isOn: $viewModel.launchAtLogin) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Launch at Login")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Automatically start GitBar when you log in")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                            .toggleStyle(.switch)
                            .tint(Theme.accent)
                            .padding(16)
                        }
                    }

                    // Folders Section
                    sectionContainer(title: "FOLDERS") {
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Folder sources")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Scan these folders for git repositories")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textTertiary)
                                }

                                Spacer()

                                Button(action: addFolder) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("Add Folder")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Theme.surfaceHover)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(16)
                            
                            Divider().overlay(Theme.border)

                            if viewModel.repoFolders.isEmpty {
                                Text("No folders added")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.repoFolders, id: \.self) { folderPath in
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(URL(fileURLWithPath: folderPath).lastPathComponent)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(Theme.textPrimary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)

                                                Text(folderPath)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Theme.textTertiary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }

                                            Spacer()

                                            Button(action: { viewModel.removeRepoFolder(folderPath) }) {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Theme.error)
                                                    .opacity(0.8)
                                            }
                                            .buttonStyle(.plain)
                                            .help("Remove folder")
                                        }
                                        .padding(12)
                                        .background(Theme.surface.opacity(0.5)) // Slightly darker row

                                        if folderPath != viewModel.repoFolders.last {
                                            Divider().overlay(Theme.border).padding(.leading, 16)
                                        }
                                    }
                                }
                                .background(Theme.surface)
                            }
                        }
                    }

                    // Updates Section
                    sectionContainer(title: "UPDATES") {
                        VStack(spacing: 0) {
                            Toggle(isOn: $viewModel.checkForUpdatesAutomatically) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Automatic Updates")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Get notified when new versions are available")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                            .toggleStyle(.switch)
                            .tint(Theme.accent)
                            .padding(16)

                            Divider().overlay(Theme.border).padding(.leading, 16)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Check for updates")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Theme.textPrimary)
                                    if viewModel.isCheckingForUpdates {
                                        Text("Checking...")
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textSecondary)
                                    } else if let lastCheck = viewModel.lastUpdateCheck {
                                        Text("Last checked: \(formatDate(lastCheck))")
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.textTertiary)
                                    }
                                }

                                Spacer()

                                Button(action: { viewModel.checkForUpdates() }) {
                                    Text("Check Now")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Theme.surfaceHover)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Theme.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isCheckingForUpdates)
                            }
                            .padding(16)
                        }
                    }

                    // About Section
                    sectionContainer(title: "ABOUT") {
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("GitBar")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Version \(viewModel.appVersion)")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textTertiary)
                                }

                                Spacer()
                            }
                            .padding(16)

                            Divider().overlay(Theme.border).padding(.leading, 16)

                            Button(action: { viewModel.openGitHub() }) {
                                HStack {
                                    Text("View on GitHub")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Theme.textPrimary)

                                    Spacer()

                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textTertiary)
                                }
                                .padding(16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(20)
            }
        }
        .frame(width: 440, height: 500)
        .background(Theme.background)
    }

    // MARK: - Helper Views

    private func sectionContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Theme.textTertiary)
                .padding(.leading, 4)

            VStack(spacing: 0, content: content)
                .background(Theme.surface)
                .cornerRadius(Theme.radius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func addFolder() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        panel.message = "Choose a folder to scan for git repositories."

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            viewModel.addRepoFolder(url.path)
        }
    }
}

#Preview {
    SettingsView()
}
