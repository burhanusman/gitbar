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

    // MARK: - OpenAI API Key

    @Published var openAIAPIKey: String = ""
    @Published var isAPIKeySaved: Bool = false
    @Published var apiKeyError: String?

    private let sparkleService = SparkleUpdateService.shared
    private let keychainService = KeychainService.shared

    var isCheckingForUpdates: Bool {
        sparkleService.isCheckingForUpdates
    }

    /// Whether any OpenAI features are available (API key is set)
    var hasOpenAIKey: Bool {
        keychainService.hasOpenAIAPIKey
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

        // Load API key status (don't show the actual key for security)
        self.isAPIKeySaved = keychainService.hasOpenAIAPIKey
    }

    /// Saves the OpenAI API key to Keychain
    func saveOpenAIAPIKey() {
        let trimmedKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            apiKeyError = "API key cannot be empty"
            return
        }

        guard trimmedKey.hasPrefix("sk-") else {
            apiKeyError = "Invalid API key format (should start with sk-)"
            return
        }

        do {
            try keychainService.saveOpenAIAPIKey(trimmedKey)
            isAPIKeySaved = true
            openAIAPIKey = "" // Clear the input for security
            apiKeyError = nil
        } catch {
            apiKeyError = "Failed to save API key: \(error.localizedDescription)"
        }
    }

    /// Removes the OpenAI API key from Keychain
    func removeOpenAIAPIKey() {
        do {
            try keychainService.deleteOpenAIAPIKey()
            isAPIKeySaved = false
            apiKeyError = nil
        } catch {
            apiKeyError = "Failed to remove API key: \(error.localizedDescription)"
        }
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
