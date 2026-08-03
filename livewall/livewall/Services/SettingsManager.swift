import Foundation
import Combine
import ServiceManagement
import os

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var pauseOnBattery: Bool {
        didSet { UserDefaults.standard.set(pauseOnBattery, forKey: "pauseOnBattery") }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard !isUpdatingLoginItem else { return }
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    @Published var lowPowerMode: Bool {
        didSet { UserDefaults.standard.set(lowPowerMode, forKey: "lowPowerMode") }
    }

    @Published var displayAssignments: [String: String] {
        didSet {
            do {
                let data = try JSONEncoder().encode(displayAssignments)
                UserDefaults.standard.set(data, forKey: "displayAssignments")
            } catch {
                AppLogger.settings.error("Failed to encode display assignments: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Re-entry guard for `launchAtLogin`'s didSet when we revert the toggle
    /// after a failed `SMAppService` call.
    private var isUpdatingLoginItem = false

    init() {
        self.pauseOnBattery = UserDefaults.standard.object(forKey: "pauseOnBattery") as? Bool ?? true
        self.launchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false
        self.lowPowerMode = UserDefaults.standard.object(forKey: "lowPowerMode") as? Bool ?? false

        if let data = UserDefaults.standard.data(forKey: "displayAssignments") {
            do {
                self.displayAssignments = try JSONDecoder().decode([String: String].self, from: data)
            } catch {
                AppLogger.settings.warning("Couldn't decode saved display assignments; resetting: \(error.localizedDescription, privacy: .public)")
                self.displayAssignments = [:]
            }
        } else {
            self.displayAssignments = [:]
        }
    }

    private func updateLoginItem() {
        if #unavailable(macOS 13.0) { return }
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            AppLogger.settings.info("Launch-at-login updated to \(self.launchAtLogin, privacy: .public)")
        } catch {
            AppLogger.settings.error("Failed to update login item: \(error.localizedDescription, privacy: .public)")
            // Revert the UI toggle so it reflects reality, without re-triggering updateLoginItem().
            isUpdatingLoginItem = true
            launchAtLogin.toggle()
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            isUpdatingLoginItem = false
        }
    }
}
