import Foundation
#if canImport(Sparkle)
import Sparkle
#endif

/// Service wrapper for Sparkle auto-updates with fallback for development
final class SparkleUpdateService: NSObject, ObservableObject {
    static let shared = SparkleUpdateService()

    #if canImport(Sparkle)
    private var updaterController: SPUStandardUpdaterController?
    #endif

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var isCheckingForUpdates = false

    private let checkForUpdatesAutomaticallyKey = "checkForUpdatesAutomatically"
    private let lastUpdateCheckKey = "lastUpdateCheck"
    private let defaults = UserDefaults.standard

    private override init() {
        super.init()
        setupUpdater()
    }

    private func setupUpdater() {
        #if canImport(Sparkle)
        // Initialize Sparkle updater controller
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        canCheckForUpdates = updaterController?.updater.canCheckForUpdates ?? false
        #else
        // Fallback mode when Sparkle is not available
        canCheckForUpdates = true
        #endif
    }

    /// Check for updates manually
    func checkForUpdates() {
        #if canImport(Sparkle)
        guard let updaterController = updaterController else {
            fallbackCheckForUpdates()
            return
        }
        isCheckingForUpdates = true
        updaterController.checkForUpdates(nil)
        #else
        fallbackCheckForUpdates()
        #endif
    }

    private func fallbackCheckForUpdates() {
        isCheckingForUpdates = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            defaults.set(Date(), forKey: lastUpdateCheckKey)
            isCheckingForUpdates = false
        }
    }

    /// Get the automatic update check setting
    var automaticallyChecksForUpdates: Bool {
        get {
            #if canImport(Sparkle)
            return updaterController?.updater.automaticallyChecksForUpdates ??
                   (defaults.object(forKey: checkForUpdatesAutomaticallyKey) as? Bool ?? true)
            #else
            return defaults.object(forKey: checkForUpdatesAutomaticallyKey) as? Bool ?? true
            #endif
        }
        set {
            #if canImport(Sparkle)
            updaterController?.updater.automaticallyChecksForUpdates = newValue
            #endif
            defaults.set(newValue, forKey: checkForUpdatesAutomaticallyKey)
        }
    }

    /// Get the last update check date
    var lastUpdateCheckDate: Date? {
        #if canImport(Sparkle)
        return updaterController?.updater.lastUpdateCheckDate ??
               (defaults.object(forKey: lastUpdateCheckKey) as? Date)
        #else
        return defaults.object(forKey: lastUpdateCheckKey) as? Date
        #endif
    }
}

#if canImport(Sparkle)
// MARK: - SPUUpdaterDelegate
extension SparkleUpdateService: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        isCheckingForUpdates = false
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        isCheckingForUpdates = false
        print("Update check failed: \(error.localizedDescription)")
    }
}
#endif
