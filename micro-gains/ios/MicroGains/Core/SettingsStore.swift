import Foundation

/// Settings live in UserDefaults as one Codable blob. Small, synchronous, and
/// safe to read from the notification action path.
final class SettingsStore: @unchecked Sendable {
    static let shared = SettingsStore()

    private enum Key {
        static let settings = "settings"
        static let onboardingCompleted = "onboarding_completed"
        static let permissionExplainerShown = "permission_explainer_shown"
        static let catalogRefreshedAt = "catalog_refreshed_at"
        static let needsPush = "settings_needs_push"
    }

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var cached: AppSettings?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var current: AppSettings {
        get {
            lock.lock(); defer { lock.unlock() }
            if let cached { return cached }
            guard let data = defaults.data(forKey: Key.settings),
                  var decoded = try? Self.decoder.decode(AppSettings.self, from: data)
            else {
                let fresh = AppSettings.default
                cached = fresh
                return fresh
            }
            // An older build (or a hand-edited file) could hold a window the
            // server would reject. Never hand one of those out.
            decoded.repairWindow()
            cached = decoded
            return decoded
        }
        set { write(newValue, markDirty: true) }
    }

    /// Writes settings the server just handed us. Same as `current = ...` minus
    /// the dirty flag, so a bootstrap read does not bounce straight back as a PUT.
    func adopt(_ settings: AppSettings) {
        write(settings, markDirty: false)
    }

    private func write(_ settings: AppSettings, markDirty: Bool) {
        var settings = settings
        // Rule: an invalid window is repaired, never persisted.
        settings.repairWindow()
        lock.lock()
        cached = settings
        lock.unlock()
        if let data = try? Self.encoder.encode(settings) {
            defaults.set(data, forKey: Key.settings)
        }
        if markDirty { needsPush = true }
    }

    /// The device zone is the truth, and it changes while the app is asleep.
    /// Called on launch, on every foreground and from `NSSystemTimeZoneDidChange`
    /// before anything replans. Returns true when the stored zone moved, which
    /// is the caller's cue to push and reschedule.
    @discardableResult
    func refreshTimeZone(to identifier: String = TimeZone.autoupdatingCurrent.identifier) -> Bool {
        var settings = current
        guard settings.timezone != identifier, TimeZone(identifier: identifier) != nil else { return false }
        settings.timezone = identifier
        current = settings
        return true
    }

    /// True while the local settings have an edit the server has not accepted.
    /// Survives a relaunch, so a push that failed offline is retried on the next
    /// foreground rather than waiting for another edit.
    var needsPush: Bool {
        get { defaults.bool(forKey: Key.needsPush) }
        set { defaults.set(newValue, forKey: Key.needsPush) }
    }

    var hasStoredSettings: Bool { defaults.data(forKey: Key.settings) != nil }

    var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Key.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Key.onboardingCompleted) }
    }

    var permissionExplainerShown: Bool {
        get { defaults.bool(forKey: Key.permissionExplainerShown) }
        set { defaults.set(newValue, forKey: Key.permissionExplainerShown) }
    }

    var catalogRefreshedAt: Date? {
        get { defaults.object(forKey: Key.catalogRefreshedAt) as? Date }
        set { defaults.set(newValue, forKey: Key.catalogRefreshedAt) }
    }

    func reset() {
        lock.lock()
        cached = nil
        lock.unlock()
        for key in [Key.settings, Key.onboardingCompleted, Key.permissionExplainerShown, Key.catalogRefreshedAt, Key.needsPush, "catalog_version"] {
            defaults.removeObject(forKey: key)
        }
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601.utc.string(from: date))
        }
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = ISO8601.parse(raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "bad date \(raw)")
                )
            }
            return date
        }
        return decoder
    }()
}
