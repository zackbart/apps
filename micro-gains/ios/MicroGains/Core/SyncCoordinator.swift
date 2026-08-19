import Foundation

extension Notification.Name {
    /// Posted on the main queue whenever the set log or settings change, so the
    /// screens can reload without polling.
    static let microGainsDataChanged = Notification.Name("microGainsDataChanged")
}

/// Best-effort server sync. Settings go up after every edit, finished sets are
/// queued locally and flushed on foreground and after each log, and the catalog
/// is refreshed once a day. Every failure is silent and retried next time.
actor SyncCoordinator {
    static let shared = SyncCoordinator()

    private let api: APIClient
    private let store: SetStore
    private let settingsStore: SettingsStore
    private let catalog: Catalog
    private var flushing = false

    /// One settings PUT at a time. Edits made while one is in flight bump the
    /// revision and the in-flight task loops again with the newest snapshot, so
    /// two fast edits can never land on the server in the wrong order.
    private var pendingSettings: AppSettings?
    private var settingsRevision: UInt64 = 0
    private var sendingSettings = false

    init(
        api: APIClient = .shared,
        store: SetStore = .shared,
        settingsStore: SettingsStore = .shared,
        catalog: Catalog = .shared
    ) {
        self.api = api
        self.store = store
        self.settingsStore = settingsStore
        self.catalog = catalog
    }

    /// Fresh install with no local settings: adopt whatever the server has.
    /// Otherwise the client wins and we say nothing.
    func bootstrap() async {
        guard !settingsStore.hasStoredSettings else { return }
        guard let response = try? await api.me() else { return }
        var settings = response.settings
        settings.timezone = TimeZone.autoupdatingCurrent.identifier
        settingsStore.adopt(settings)
        await MainActor.run { NotificationCenter.default.post(name: .microGainsDataChanged, object: nil) }
    }

    // MARK: - Settings

    /// Queues `settings` for the server. Returns once the queue is drained or
    /// another caller has taken over the send.
    func pushSettings(_ settings: AppSettings) async {
        settingsRevision &+= 1
        pendingSettings = settings
        settingsStore.needsPush = true
        await drainSettings()
    }

    /// Foreground hook. A push that failed while offline is retried here rather
    /// than waiting for the user to edit something again.
    func flushSettingsIfNeeded() async {
        guard settingsStore.needsPush else { return }
        if pendingSettings == nil { pendingSettings = settingsStore.current }
        await drainSettings()
    }

    private func drainSettings() async {
        // An in-flight send picks up whatever arrived while it was waiting.
        guard !sendingSettings else { return }
        sendingSettings = true
        defer { sendingSettings = false }

        while settingsStore.needsPush, let snapshot = pendingSettings {
            let revision = settingsRevision
            do {
                _ = try await api.putSettings(snapshot)
            } catch {
                // Offline or refused. Keep the flag so the next foreground tries.
                return
            }
            // Anything newer arrived mid-flight, so go round again with it.
            guard settingsRevision == revision else { continue }
            settingsStore.needsPush = false
        }
    }

    // MARK: - Set outbox

    /// A rejection the server will repeat no matter how often we ask. These are
    /// settled locally; everything else stays in the outbox for another pass.
    /// See server/src/validation.ts for the code list.
    static func isPermanentRejection(_ error: String) -> Bool {
        error == "unknown_exercise" || error.hasPrefix("invalid_")
    }

    func flushOutbox() async {
        guard !flushing else { return }
        flushing = true
        defer { flushing = false }

        let pending = await store.outbox()
        guard !pending.isEmpty else { return }
        guard let response = try? await api.postSets(pending) else { return }

        // Accepted and duplicate are settled, and so is a set the server will
        // never take. A rejection that might be transient (a rate limit, a
        // server-side wobble) keeps its record for the next pass, up to
        // SetStore.maxSyncAttempts tries.
        let retryIDs = response.rejected
            .filter { !Self.isPermanentRejection($0.error) }
            .map(\.id)
        let retrySet = Set(retryIDs)
        let settled = pending.map(\.id).filter { !retrySet.contains($0) }

        await store.markSynced(ids: settled)
        if !retryIDs.isEmpty {
            let abandoned = await store.markSyncRetry(ids: retryIDs)
            if !abandoned.isEmpty {
                NSLog("[MicroGains] gave up on %d rejected set(s) after %d tries",
                      abandoned.count, SetStore.maxSyncAttempts)
            }
        }
    }

    func refreshCatalogIfStale(now: Date = Date()) async {
        if let last = settingsStore.catalogRefreshedAt, now.timeIntervalSince(last) < 24 * 3600 {
            return
        }
        guard let response = try? await api.catalog(etag: catalog.version) else {
            // A 304 also lands here as nil; either way the local copy stands.
            settingsStore.catalogRefreshedAt = now
            return
        }
        catalog.replace(with: response.exercises, version: response.version)
        settingsStore.catalogRefreshedAt = now
    }

    func serverHistory(days: Int = 30) async -> APIClient.HistoryResponse? {
        try? await api.history(days: days)
    }

    /// Settings screen "Erase my data". The server call is best-effort; the
    /// local wipe and the device id rotation happen regardless.
    func eraseEverything() async {
        try? await api.deleteMe()
        await store.wipe()
        settingsStore.reset()
        DeviceID.rotate()
    }
}
