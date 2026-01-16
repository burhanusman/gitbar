import Foundation
import SwiftUI

/// ViewModel for app settings
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet {
            SettingsService.shared.launchAtLogin = launchAtLogin
        }
    }

    @Published var checkForUpdatesAutomatically: Bool {
        didSet {
            SettingsService.shared.checkForUpdatesAutomatically = checkForUpdatesAutomatically
        }
    }

    @Published var isCheckingForUpdates = false
    @Published var lastUpdateCheck: Date?

    let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }()

    @Published private(set) var repoFolders: [String]

    init() {
        // Sync with system state first
        SettingsService.shared.syncLoginItemStatus()
        // Then read the current values
        self.launchAtLogin = SettingsService.shared.launchAtLogin
        self.checkForUpdatesAutomatically = SettingsService.shared.checkForUpdatesAutomatically
        self.lastUpdateCheck = SettingsService.shared.lastUpdateCheck
        self.repoFolders = SettingsService.shared.repoFolders
    }

    func addRepoFolder(_ path: String) {
        SettingsService.shared.addRepoFolder(path)
        repoFolders = SettingsService.shared.repoFolders
    }

    func removeRepoFolder(_ path: String) {
        SettingsService.shared.removeRepoFolder(path)
        repoFolders = SettingsService.shared.repoFolders
    }

    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }

        isCheckingForUpdates = true

        // Simulate checking for updates (in a real app, this would check GitHub releases API)
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            let now = Date()
            SettingsService.shared.lastUpdateCheck = now
            lastUpdateCheck = now
            isCheckingForUpdates = false

            // In a real implementation, you would:
            // 1. Fetch latest release from GitHub API
            // 2. Compare with current version
            // 3. Show alert if update available
        }
    }

    func openGitHub() {
        if let url = URL(string: "https://github.com/yourusername/gitbar") {
            NSWorkspace.shared.open(url)
        }
    }
}
