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
            sparkleService.automaticallyChecksForUpdates = checkForUpdatesAutomatically
        }
    }

    @Published var lastUpdateCheck: Date?

    let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }()

    @Published private(set) var repoFolders: [String]

    private let sparkleService = SparkleUpdateService.shared

    var isCheckingForUpdates: Bool {
        sparkleService.isCheckingForUpdates
    }

    init() {
        // Sync with system state first
        SettingsService.shared.syncLoginItemStatus()
        // Then read the current values
        self.launchAtLogin = SettingsService.shared.launchAtLogin
        self.repoFolders = SettingsService.shared.repoFolders

        // Initialize from Sparkle
        self.checkForUpdatesAutomatically = sparkleService.automaticallyChecksForUpdates
        self.lastUpdateCheck = sparkleService.lastUpdateCheckDate
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
        sparkleService.checkForUpdates()
        // Update lastUpdateCheck after a short delay to allow Sparkle to update
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            lastUpdateCheck = sparkleService.lastUpdateCheckDate
        }
    }

    func openGitHub() {
        if let url = URL(string: "https://github.com/burhanusman/gitbar") {
            NSWorkspace.shared.open(url)
        }
    }
}
