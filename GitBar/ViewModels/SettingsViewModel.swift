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

    init() {
        // Sync with system state first
        SettingsService.shared.syncLoginItemStatus()
        // Then read the current value
        self.launchAtLogin = SettingsService.shared.launchAtLogin
    }
}
