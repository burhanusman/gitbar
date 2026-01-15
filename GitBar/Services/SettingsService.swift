import Foundation
import ServiceManagement

/// Service for managing app settings including launch at login
final class SettingsService {
    static let shared = SettingsService()

    private let launchAtLoginKey = "launchAtLogin"
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
