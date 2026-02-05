import Foundation
import ServiceManagement

/// How projects should be sorted in the sidebar
enum ProjectSortMode: String, CaseIterable {
    case alphabetical = "alphabetical"
    case recent = "recent"

    var displayName: String {
        switch self {
        case .alphabetical: return "Alphabetical"
        case .recent: return "Recent Activity"
        }
    }

    var iconName: String {
        switch self {
        case .alphabetical: return "textformat.abc"
        case .recent: return "clock"
        }
    }
}

extension Notification.Name {
    static let repoFoldersDidChange = Notification.Name("SettingsService.repoFoldersDidChange")
    static let projectSortModeDidChange = Notification.Name("SettingsService.projectSortModeDidChange")
}

/// Service for managing app settings including launch at login
final class SettingsService {
    static let shared = SettingsService()

    private let launchAtLoginKey = "launchAtLogin"
    private let repoFoldersKey = "repoFolders"
    private let lastSelectedProjectPathKey = "lastSelectedProjectPath"
    private let projectSortModeKey = "projectSortMode"
    private let worktreeAgentLabelsKey = "worktreeAgentLabels"
    private let lastSelectedWorktreePathKey = "lastSelectedWorktreePath"
    private let defaults = UserDefaults.standard

    private init() {}

    /// How projects are sorted in the sidebar
    var projectSortMode: ProjectSortMode {
        get {
            guard let rawValue = defaults.string(forKey: projectSortModeKey),
                  let mode = ProjectSortMode(rawValue: rawValue) else {
                return .alphabetical
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: projectSortModeKey)
            NotificationCenter.default.post(name: .projectSortModeDidChange, object: nil)
        }
    }

    /// Last selected project path (for restoring selection on app launch)
    var lastSelectedProjectPath: String? {
        get {
            defaults.string(forKey: lastSelectedProjectPathKey)
        }
        set {
            defaults.set(newValue, forKey: lastSelectedProjectPathKey)
        }
    }

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

    // MARK: - Worktree Settings

    /// Agent labels keyed by worktree path
    var worktreeAgentLabels: [String: String] {
        get {
            defaults.dictionary(forKey: worktreeAgentLabelsKey) as? [String: String] ?? [:]
        }
        set {
            defaults.set(newValue, forKey: worktreeAgentLabelsKey)
        }
    }

    /// Sets an agent label for a worktree path
    func setAgentLabel(_ label: String?, forWorktreePath path: String) {
        var labels = worktreeAgentLabels
        labels[path] = label
        worktreeAgentLabels = labels
    }

    /// Gets the agent label for a worktree path
    func agentLabel(forWorktreePath path: String) -> String? {
        worktreeAgentLabels[path]
    }

    /// Last selected worktree path (for restoring selection on app launch)
    var lastSelectedWorktreePath: String? {
        get {
            defaults.string(forKey: lastSelectedWorktreePathKey)
        }
        set {
            defaults.set(newValue, forKey: lastSelectedWorktreePathKey)
        }
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
