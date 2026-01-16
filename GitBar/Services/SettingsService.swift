import Foundation
import ServiceManagement

extension Notification.Name {
    static let repoFoldersDidChange = Notification.Name("SettingsService.repoFoldersDidChange")
}

/// Service for managing app settings including launch at login
final class SettingsService {
    static let shared = SettingsService()

    private let launchAtLoginKey = "launchAtLogin"
    private let repoFoldersKey = "repoFolders"
    private let checkForUpdatesAutomaticallyKey = "checkForUpdatesAutomatically"
    private let lastUpdateCheckKey = "lastUpdateCheck"
    private let defaults = UserDefaults.standard

    private init() {}

    /// Gets the current launch at login setting from UserDefaults
    var launchAtLogin: Bool {
        get {
            defaults.bool(forKey: launchAtLoginKey)
        }
        set {
            defaults.set(newValue, forKey: launchAtLoginKey)
            updateLoginItem(enabled: newValue)
        }
    }

    /// User-selected parent folders to scan for Git repositories
    var repoFolders: [String] {
        get {
            (defaults.stringArray(forKey: repoFoldersKey) ?? [])
                .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        }
        set {
            let normalized = Array(Set(newValue.map { URL(fileURLWithPath: $0).standardizedFileURL.path }))
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            defaults.set(normalized, forKey: repoFoldersKey)
            NotificationCenter.default.post(name: .repoFoldersDidChange, object: nil)
        }
    }

    /// Gets the current auto-update preference from UserDefaults
    var checkForUpdatesAutomatically: Bool {
        get {
            defaults.object(forKey: checkForUpdatesAutomaticallyKey) as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: checkForUpdatesAutomaticallyKey)
        }
    }

    /// Gets the last time updates were checked
    var lastUpdateCheck: Date? {
        get {
            defaults.object(forKey: lastUpdateCheckKey) as? Date
        }
        set {
            defaults.set(newValue, forKey: lastUpdateCheckKey)
        }
    }

    func addRepoFolder(_ path: String) {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard !normalized.isEmpty else { return }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: normalized, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }

        var folders = repoFolders
        guard !folders.contains(normalized) else { return }
        folders.append(normalized)
        repoFolders = folders
    }

    func removeRepoFolder(_ path: String) {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        var folders = repoFolders
        folders.removeAll { $0 == normalized }
        repoFolders = folders
    }

    /// Updates the SMAppService login item registration
    private func updateLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
            }
        }
    }

    /// Syncs the current login item status from the system
    /// Call this on app launch to ensure UserDefaults matches system state
    func syncLoginItemStatus() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            let isRegistered = status == .enabled

            // Update UserDefaults if out of sync with system
            if defaults.bool(forKey: launchAtLoginKey) != isRegistered {
                defaults.set(isRegistered, forKey: launchAtLoginKey)
            }
        }
    }
}
