import Foundation
import Combine

@MainActor
final class VaultSession: ObservableObject {
    @Published private(set) var passkeys: [VaultPasskey] = []
    @Published private(set) var entries: [VaultEntry] = []
    @Published private(set) var vaults: [VaultSummary] = []
    @Published private(set) var isUnlocked = false
    @Published private(set) var isConfigured = false
    @Published private(set) var isInitializing = true
    @Published private(set) var isBusy = false
    @Published var lastError: String?
    @Published private(set) var initializationError: String?
    @Published private(set) var syncState = "idle"
    @Published private(set) var syncError: String?
    private var engine: (any VaultEngineAccess)?
    private let keyStorage: any DeviceKeyStorage
    private var generation = 0
    private var syncTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var importing = false
    private var pendingSync = false
    private var syncRevision = 0
    private var cancellingSync = false
    private var authentication: DeviceAuthentication?

    init() {
        keyStorage = LiveDeviceKeyStorage()
        do {
            engine = try VaultEngine()
            initialize()
        } catch {
            lastError = error.localizedDescription
            initializationError = error.localizedDescription
            isInitializing = false
        }
    }

    init(engine: any VaultEngineAccess, keyStorage: any DeviceKeyStorage = LiveDeviceKeyStorage(), initialize: Bool = true) {
        self.engine = engine
        self.keyStorage = keyStorage
        if initialize { self.initialize() } else { isInitializing = false }
    }

    private func initialize() {
        Task {
            defer { isInitializing = false }
            do { try await refreshStatus() }
            catch {
                lastError = error.localizedDescription
                initializationError = error.localizedDescription
            }
        }
    }

    private func available() throws -> any VaultEngineAccess {
        guard let engine else { throw VaultFailure.unavailable("The shared vault is unavailable.") }
        return engine
    }

    private func requireGeneration(_ current: Int, unlocked: Bool = false) throws {
        try Task.checkCancellation()
        guard current == generation, !unlocked || isUnlocked else { throw CancellationError() }
    }

    private func applyStatus(_ status: Any) throws {
        guard let status = status as? [String: Any], let initialized = status["initialized"] as? Bool else {
            throw VaultFailure.unavailable("Invalid vault status response.")
        }
        initializationError = nil
        isConfigured = initialized
        vaults = (status["vaults"] as? [[String: Any]] ?? []).compactMap(VaultSummary.init)
    }

    func refreshStatus() async throws {
        let current = generation
        let status = try await available().perform("status")
        try requireGeneration(current)
        try applyStatus(status)
    }

    func create(password: String, deviceName: String = "iPhone", vaultName: String = "personal") async throws {
        try await unlockOperation("create", ["passphrase": password, "device_name": deviceName, "vault_name": vaultName])
    }

    func prepareToJoin(password: String) async throws {
        guard !isBusy else { throw VaultFailure.unavailable("A vault operation is already running.") }
        isBusy = true
        defer { isBusy = false }
        let current = generation
        do {
            let status = try await available().perform("create", ["passphrase": password, "device_name": "iPhone", "vault_name": ""])
            try requireGeneration(current)
            try applyStatus(status)
        } catch {
            await recoverStatusAfterCreate()
            throw error
        }
    }

    private func recoverStatusAfterCreate() async {
        _ = await Task { @MainActor [weak self] in try? await self?.refreshStatus() }.value
    }

    func finishJoin() async throws {
        let current = generation
        try await refreshContents(current: current)
        try await refreshStatus()
        try requireGeneration(current)
        isUnlocked = true
        startRefreshing()
        await updateIdentities(current: current)
        scheduleSync()
    }

    func unlock(password: String) async throws { try await unlockOperation("unlock", ["passphrase": password]) }

    func unlockWithDeviceAuthentication() async throws {
        guard !isBusy else { throw VaultFailure.unavailable("A vault operation is already running.") }
        isBusy = true
        defer { isBusy = false }
        let current = generation
        let authentication = DeviceAuthentication()
        self.authentication = authentication
        defer { self.authentication = nil }
        let key = try await withTaskCancellationHandler {
            try await Task.detached { try authentication.read() }.value
        } onCancel: { authentication.cancel() }
        try requireGeneration(current)
        try await activate("unlock_key", arguments: ["key": key], current: current)
    }

    private func unlockOperation(_ operation: String, _ arguments: [String: Any]) async throws {
        guard !isBusy else { throw VaultFailure.unavailable("A vault operation is already running.") }
        isBusy = true
        defer { isBusy = false }
        try await activate(operation, arguments: arguments, current: generation)
    }

    private func activate(_ operation: String, arguments: [String: Any], current: Int) async throws {
        let engine = try available()
        do {
            let status = try await engine.perform(operation, arguments)
            try requireGeneration(current)
            try applyStatus(status)
            try await refreshContents(current: current)
            try requireGeneration(current)
            isUnlocked = true
            startRefreshing()
            await updateIdentities(current: current)
            scheduleSync()
        } catch {
            if current == generation { lock() }
            if operation == "create" { await recoverStatusAfterCreate() }
            throw error
        }
    }

    func createVault(name: String) async throws -> VaultSummary {
        guard isUnlocked else { throw VaultFailure.unavailable("Unlock the vault first.") }
        let current = generation
        let result = try await available().perform("create_vault", ["name": name])
        guard let object = result as? [String: Any], let created = VaultSummary(object) else {
            throw VaultFailure.unavailable("The vault was created. Reopen Deadbolt to reload the vault list before creating another.")
        }
        guard current == generation, isUnlocked else { return created }
        if !vaults.contains(where: { $0.id == created.id }) { vaults.append(created) }
        do { try await refreshStatus() }
        catch { if current == generation, isUnlocked { lastError = "Your vault was created. The vault list could not refresh." } }
        if current == generation, isUnlocked { scheduleSync() }
        return created
    }

    func enableDeviceAuthentication() async throws {
        guard isUnlocked, !isBusy else { throw VaultFailure.unavailable("Unlock the vault before enabling device authentication.") }
        isBusy = true
        defer { isBusy = false }
        let engine = try available()
        let current = generation
        do {
            guard let result = try await engine.perform("biometric_enable") as? [String: Any], let key = result["key"] as? String else {
                throw VaultFailure.unavailable("The device unlock key could not be created.")
            }
            try requireGeneration(current, unlocked: true)
            try keyStorage.save(key)
        } catch {
            try? keyStorage.remove()
            if current == generation, isUnlocked { _ = try? await engine.perform("biometric_disable") }
            throw error
        }
    }

    func disableDeviceAuthentication() async throws {
        guard isUnlocked, !isBusy else { throw VaultFailure.unavailable("Unlock the vault first.") }
        isBusy = true
        defer { isBusy = false }
        try keyStorage.remove()
        _ = try await available().perform("biometric_disable")
    }

    func lock() {
        authentication?.cancel()
        authentication = nil
        syncTask?.cancel()
        syncTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        generation += 1
        entries.removeAll(keepingCapacity: false)
        passkeys.removeAll(keepingCapacity: false)
        vaults.removeAll(keepingCapacity: false)
        isUnlocked = false
        syncState = "idle"
        syncError = nil
        pendingSync = false
        cancellingSync = false
        syncRevision += 1
        engine?.enqueueLock()
    }

    private func saveArguments(_ entry: VaultEntry, original: VaultEntry?) throws -> [String: Any] {
        let vaultID = entry.vaultID ?? (vaults.count == 1 ? vaults[0].id : nil)
        guard let vaultID, vaults.contains(where: { $0.id == vaultID }) else { throw VaultFailure.unavailable("Choose a vault for this login.") }
        if let original {
            guard original.id == entry.id, original.vaultID == vaultID,
                  let current = entries.first(where: { $0.id == original.id && $0.vaultID == vaultID }), current == original else {
                throw VaultFailure.unavailable("This login changed or was deleted on another device. Reopen it before editing.")
            }
        }
        let edited: [String: [String: String]] = ["username": ["type": "text", "value": entry.username], "password": ["type": "secret", "value": entry.password], "url": ["type": "url", "value": entry.url], "notes": ["type": "note", "value": entry.notes], "otp": ["type": "otp", "value": entry.totp]]
        let changed = edited.filter { original == nil || original?.extraFields[$0.key] != $0.value }
        let removed = changed.filter { $0.value["value"]?.isEmpty == true }.map(\.key)
        var arguments: [String: Any] = ["type": "login", "name": entry.title, "fields": changed.filter { $0.value["value"]?.isEmpty == false }, "remove_fields": removed, "vault_id": vaultID]
        if let original {
            arguments["id"] = original.id
            arguments["expected"] = ["name": original.title, "fields": original.extraFields] as [String: Any]
        }
        return arguments
    }

    func save(entry: VaultEntry, original: VaultEntry? = nil) async throws {
        guard isUnlocked, !importing else { throw VaultFailure.unavailable("Unlock the vault and finish any import first.") }
        let current = generation
        _ = try await available().perform("save", saveArguments(entry, original: original))
        guard current == generation, isUnlocked else { return }
        await refreshAfterCommit(current: current)
    }

    func importEntries(_ rows: [VaultEntry], vaultID: String) async throws -> VaultImportSummary {
        guard isUnlocked, !importing, vaults.contains(where: { $0.id == vaultID }) else {
            throw VaultFailure.unavailable("Unlock and choose a vault before importing.")
        }
        guard !rows.isEmpty else { return VaultImportSummary(imported: 0, skipped: 0) }
        importing = true
        defer { importing = false }
        let current = generation
        let items = try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            return rows.map { entry -> [String: Any] in
                let values: [String: [String: String]] = ["username": ["type": "text", "value": entry.username], "password": ["type": "secret", "value": entry.password], "url": ["type": "url", "value": entry.url], "notes": ["type": "note", "value": entry.notes], "otp": ["type": "otp", "value": entry.totp]]
                return ["type": "login", "name": entry.title, "fields": values.filter { $0.value["value"]?.isEmpty == false }]
            }
        }.value
        try requireGeneration(current, unlocked: true)
        guard let result = try await available().perform("import", ["vault_id": vaultID, "items": items, "deduplicate": true]) as? [String: Any],
              let imported = result["imported"] as? Int, let skipped = result["skipped"] as? Int,
              imported >= 0, imported <= rows.count, skipped == rows.count - imported else {
            throw VaultFailure.unavailable("Import results could not be confirmed. Retrying the same file will skip exact duplicates.")
        }
        importing = false
        await refreshAfterCommit(current: current)
        return VaultImportSummary(imported: imported, skipped: skipped)
    }

    func importCredentialExchange(_ records: [CredentialExchangeRecord], vaultID: String) async throws -> VaultImportSummary {
        guard isUnlocked, !importing, vaults.contains(where: { $0.id == vaultID }) else {
            throw VaultFailure.unavailable("Unlock and choose a vault before importing.")
        }
        guard !records.isEmpty else { return VaultImportSummary(imported: 0, skipped: 0) }
        importing = true
        defer { importing = false }
        let current = generation
        let items = records.map(\.payload)
        try requireGeneration(current, unlocked: true)
        guard let result = try await available().perform("credential_exchange_import", ["vault_id": vaultID, "items": items]) as? [String: Any],
              let imported = result["imported"] as? Int, let skipped = result["skipped"] as? Int,
              imported >= 0, skipped >= 0, imported + skipped == records.count else {
            throw VaultFailure.unavailable("Import results could not be confirmed. Start the transfer again; items already saved are skipped.")
        }
        importing = false
        await refreshAfterCommit(current: current)
        return VaultImportSummary(imported: imported, skipped: skipped)
    }

    func delete(id: String) async throws {
        guard isUnlocked, !importing, let entry = entries.first(where: { $0.id == id }) else { throw VaultFailure.unavailable("Credential unavailable.") }
        let current = generation
        var arguments: [String: Any] = ["id": id]
        if let vaultID = entry.vaultID { arguments["vault_id"] = vaultID }
        _ = try await available().perform("delete", arguments)
        if current == generation, isUnlocked { entries.removeAll(where: { $0.id == id }) }
        await refreshAfterCommit(current: current)
    }

    private func refreshContents(current: Int) async throws {
        let engine = try available()
        let refreshed = try await engine.entries()
        try requireGeneration(current)
        guard let records = try await engine.perform("passkey_list") as? [[String: Any]] else { throw VaultFailure.unavailable("Invalid passkey list response.") }
        try requireGeneration(current)
        entries = refreshed
        passkeys = records.compactMap(VaultPasskey.init)
    }

    private func refreshAfterCommit(current: Int) async {
        guard current == generation, isUnlocked, !Task.isCancelled else { return }
        do { try await refreshContents(current: current) }
        catch {
            if current == generation, isUnlocked { lastError = "Your change was saved. The list could not refresh; reopen the vault to reload it." }
        }
        await updateIdentities(current: current)
        if current == generation, isUnlocked { scheduleSync() }
    }

    private func updateIdentities(current: Int) async {
        guard current == generation, isUnlocked, !Task.isCancelled else { return }
        do { try await available().publishIdentities(entries) }
        catch {
            if current == generation, isUnlocked { lastError = "Your vault is saved. AutoFill suggestions could not update; unlock Deadbolt again to retry." }
        }
    }

    private func startRefreshing() {
        refreshTask?.cancel()
        let current = generation
        refreshTask = Task {
            while !Task.isCancelled, current == generation, isUnlocked {
                do {
                    try await Task.sleep(for: .seconds(5))
                    try requireGeneration(current, unlocked: true)
                    try await refreshNow()
                } catch { if Task.isCancelled || current != generation { return } }
            }
        }
    }

    func refreshNow() async throws {
        let current = generation
        try requireGeneration(current, unlocked: true)
        try await pollSync(current: current)
        if importing { return }
        let oldEntries = entries
        let oldPasskeys = passkeys
        try await refreshContents(current: current)
        try await refreshStatus()
        try requireGeneration(current, unlocked: true)
        if oldEntries != entries || oldPasskeys != passkeys { await updateIdentities(current: current) }
    }

    func scheduleSync() {
        guard isUnlocked, !importing else { return }
        if syncState == "running" || cancellingSync { pendingSync = true; return }
        syncTask?.cancel()
        let current = generation
        syncTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(700))
                try requireGeneration(current, unlocked: true)
                try await startSync()
            } catch {
                if current == generation, isUnlocked, !Task.isCancelled { lastError = "Sync is unavailable. Your local vault remains available." }
            }
        }
    }

    private func applySyncStatus(_ value: Any) throws {
        guard let status = value as? [String: Any], let state = status["state"] as? String, ["idle", "running", "complete", "failed"].contains(state) else { throw VaultFailure.unavailable("Invalid sync status response.") }
        syncState = state
        let failed = (status["results"] as? [[String: Any]] ?? []).contains { $0["ok"] as? Bool != true }
        syncError = status["error"] as? String ?? (failed ? "Some devices could not sync. Check their connection and try again." : nil)
    }

    func syncNow() async throws {
        if syncState == "running" || cancellingSync { pendingSync = true; return }
        syncTask?.cancel()
        syncTask = nil
        try await startSync()
    }

    private func startSync() async throws {
        guard isUnlocked else { throw VaultFailure.unavailable("Unlock the vault first.") }
        if syncState == "running" || cancellingSync { pendingSync = true; return }
        let current = generation
        syncRevision += 1
        let revision = syncRevision
        syncState = "running"
        syncError = nil
        do {
            let status = try await available().perform("sync")
            try requireGeneration(current, unlocked: true)
            guard revision == syncRevision else { return }
            try applySyncStatus(status)
        } catch {
            if current == generation, revision == syncRevision, !Task.isCancelled {
                syncState = "failed"
                syncError = error.localizedDescription
            }
            throw error
        }
    }

    func cancelSync() async throws {
        guard isUnlocked else { throw VaultFailure.unavailable("Unlock the vault first.") }
        guard !cancellingSync else { return }
        syncTask?.cancel()
        syncTask = nil
        pendingSync = false
        cancellingSync = true
        syncRevision += 1
        let current = generation
        let revision = syncRevision
        defer {
            if current == generation, revision == syncRevision {
                cancellingSync = false
                if pendingSync {
                    pendingSync = false
                    scheduleSync()
                }
            }
        }
        do {
            let status = try await available().perform("sync_cancel")
            try requireGeneration(current, unlocked: true)
            guard revision == syncRevision else { return }
            try applySyncStatus(status)
        } catch {
            if current == generation, revision == syncRevision {
                syncState = "failed"
                syncError = error.localizedDescription
            }
            throw error
        }
    }

    private func pollSync(current: Int) async throws {
        guard syncState == "running", !cancellingSync else { return }
        let revision = syncRevision
        let status = try await available().perform("sync_status")
        try requireGeneration(current, unlocked: true)
        guard revision == syncRevision else { return }
        try applySyncStatus(status)
        if syncState != "running" { syncRevision += 1 }
        if syncState != "running", pendingSync {
            pendingSync = false
            scheduleSync()
        }
    }

    func refreshPasskeys() async throws {
        let current = generation
        guard let records = try await available().perform("passkey_list") as? [[String: Any]] else { throw VaultFailure.unavailable("Invalid passkey list response.") }
        try requireGeneration(current)
        passkeys = records.compactMap(VaultPasskey.init)
    }

    func deletePasskey(_ passkey: VaultPasskey) async throws {
        guard isUnlocked, !importing else { throw VaultFailure.unavailable("Unlock the vault first.") }
        let current = generation
        _ = try await available().perform("delete", ["id": passkey.id, "vault_id": passkey.vaultID])
        if current == generation, isUnlocked { passkeys.removeAll(where: { $0.id == passkey.id }) }
        await refreshAfterCommit(current: current)
    }

    func operation(_ name: String, arguments: [String: Any] = [:]) async throws -> Any {
        let current = generation
        let result = try await available().perform(name, arguments)
        try requireGeneration(current)
        if isUnlocked, !importing, ["sync", "approve", "remove_device"].contains(name) {
            try await refreshContents(current: current)
            try await refreshStatus()
        }
        if name == "pairing_status" { try await refreshStatus() }
        try requireGeneration(current)
        return result
    }
}
