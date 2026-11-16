import XCTest
@testable import Deadbolt

@MainActor
final class VaultSessionTests: XCTestCase {
    private func login(_ id: String = UUID().uuidString) -> VaultEntry {
        VaultEntry(id: id, title: "Example", username: "alice", password: "secret", url: "https://example.com", notes: "", vaultID: "vault")
    }

    func testLateUnlockCannotRestoreSecretsAfterLock() async throws {
        let engine = SessionTestEngine()
        let gate = SessionTestGate()
        let started = expectation(description: "unlock started")
        engine.onPerform = { operation, _ in
            if operation == "unlock" {
                started.fulfill()
                await gate.wait()
            }
            return engine.response(operation)
        }
        let session = VaultSession(engine: engine, initialize: false)
        let task = Task { try await session.unlock(password: "password") }
        await fulfillment(of: [started], timeout: 2)
        session.lock()
        await gate.open()
        do { try await task.value; XCTFail("Cancelled unlock must not report success") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertFalse(session.isUnlocked)
        XCTAssertTrue(session.entries.isEmpty)
        XCTAssertTrue(session.passkeys.isEmpty)
    }

    func testAtomicImportUsesOneDeduplicatedOperation() async throws {
        let engine = SessionTestEngine()
        engine.onPerform = { operation, arguments in
            if operation == "import" {
                XCTAssertEqual(arguments["deduplicate"] as? Bool, true)
                XCTAssertEqual(arguments["vault_id"] as? String, "vault")
                XCTAssertEqual((arguments["items"] as? [[String: Any]])?.count, 3)
                return ["imported": 2, "skipped": 1]
            }
            return engine.response(operation)
        }
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        let summary = try await session.importEntries([login(), login(), login()], vaultID: "vault")
        XCTAssertEqual(summary, VaultImportSummary(imported: 2, skipped: 1))
        XCTAssertEqual(engine.requests.filter { $0.0 == "import" }.count, 1)
        XCTAssertFalse(engine.requests.contains { $0.0 == "save" })
        XCTAssertEqual(engine.entryReads, 2)
    }

    func testCommittedImportStillSucceedsWhenRefreshFails() async throws {
        let engine = SessionTestEngine()
        engine.onPerform = { operation, _ in
            if operation == "import" { return ["imported": 2, "skipped": 0] }
            return engine.response(operation)
        }
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        engine.failEntryReads = true
        let summary = try await session.importEntries([login(), login()], vaultID: "vault")
        XCTAssertEqual(summary.imported, 2)
        XCTAssertEqual(engine.requests.filter { $0.0 == "import" }.count, 1)
        XCTAssertNotNil(session.lastError)
    }

    func testLockDuringAtomicImportDoesNotRestoreSecrets() async throws {
        let engine = SessionTestEngine()
        let gate = SessionTestGate()
        let started = expectation(description: "import started")
        engine.onPerform = { operation, _ in
            if operation == "import" {
                started.fulfill()
                await gate.wait()
                return ["imported": 2, "skipped": 0]
            }
            return engine.response(operation)
        }
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        let rows = [login(), login()]
        let task = Task { try await session.importEntries(rows, vaultID: "vault") }
        await fulfillment(of: [started], timeout: 2)
        session.lock()
        await gate.open()
        let summary = try await task.value
        XCTAssertEqual(summary.imported, 2)
        XCTAssertFalse(session.isUnlocked)
        XCTAssertTrue(session.entries.isEmpty)
        XCTAssertEqual(engine.entryReads, 1)
    }

    func testDeletedEditCannotBecomeNewLogin() async throws {
        let engine = SessionTestEngine()
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        let original = login("deleted-id")
        do { try await session.save(entry: original, original: original); XCTFail("Missing edit must fail") } catch {}
        XCTAssertFalse(engine.requests.contains { $0.0 == "save" })
    }

    func testEditSendsBaselineAndOnlyChangedKnownFields() async throws {
        let engine = SessionTestEngine()
        var original = login("existing-id")
        original.extraFields = ["username": ["type": "text", "value": "alice"], "password": ["type": "secret", "value": "secret"], "url": ["type": "url", "value": "https://example.com"], "custom": ["type": "secret", "value": "preserve"]]
        engine.storedEntries = [original]
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        var edited = original
        edited.username = "bob"
        try await session.save(entry: edited, original: original)
        let request = try XCTUnwrap(engine.requests.first { $0.0 == "save" }?.1)
        XCTAssertEqual(request["id"] as? String, original.id)
        let fields = try XCTUnwrap(request["fields"] as? [String: [String: String]])
        XCTAssertEqual(Set(fields.keys), ["username"])
        XCTAssertEqual(fields["username"]?["value"], "bob")
        let expected = try XCTUnwrap(request["expected"] as? [String: Any])
        XCTAssertEqual(expected["fields"] as? [String: [String: String]], original.extraFields)
    }

    func testVaultCreationStillSucceedsWhenStatusRefreshFails() async throws {
        let engine = SessionTestEngine()
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        engine.onPerform = { operation, _ in
            if operation == "status" { throw VaultFailure.unavailable("refresh unavailable") }
            if operation == "create_vault" { return ["id": "new-vault", "name": "work"] }
            return engine.response(operation)
        }
        let created = try await session.createVault(name: "work")
        XCTAssertEqual(created.id, "new-vault")
        XCTAssertTrue(session.vaults.contains(created))
        XCTAssertNotNil(session.lastError)
    }

    func testChangesDuringRunningSyncScheduleOneFollowupRound() async throws {
        let engine = SessionTestEngine()
        let followup = expectation(description: "followup sync")
        var starts = 0
        engine.onPerform = { operation, _ in
            if operation == "sync" {
                starts += 1
                if starts == 2 { followup.fulfill() }
                return ["state": starts == 1 ? "running" : "complete", "results": []] as [String: Any]
            }
            if operation == "sync_status" { return ["state": "complete", "results": []] as [String: Any] }
            return engine.response(operation)
        }
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        try await session.syncNow()
        session.scheduleSync()
        session.scheduleSync()
        try await session.refreshNow()
        await fulfillment(of: [followup], timeout: 2)
        XCTAssertEqual(starts, 2)
    }

    func testChangesWhileSyncStartResponseIsPendingAreSentInFollowup() async throws {
        let engine = SessionTestEngine()
        let gate = SessionTestGate()
        let started = expectation(description: "initial sync dispatched")
        let followup = expectation(description: "followup sync dispatched")
        var starts = 0
        engine.onPerform = { operation, _ in
            if operation == "sync" {
                starts += 1
                if starts == 1 {
                    started.fulfill()
                    await gate.wait()
                    return ["state": "running"]
                }
                followup.fulfill()
                return ["state": "complete", "results": []] as [String: Any]
            }
            if operation == "sync_status" { return ["state": "complete", "results": []] as [String: Any] }
            return engine.response(operation)
        }
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(session.syncState, "running")
        session.scheduleSync()
        session.scheduleSync()
        await gate.open()
        try await session.refreshNow()
        await fulfillment(of: [followup], timeout: 2)
        XCTAssertEqual(starts, 2)
    }

    func testChangesDuringSyncCancellationWaitForCancellationThenSync() async throws {
        let engine = SessionTestEngine()
        let gate = SessionTestGate()
        let cancelling = expectation(description: "cancel dispatched")
        let followup = expectation(description: "followup after cancel")
        var starts = 0
        engine.onPerform = { operation, _ in
            if operation == "sync" {
                starts += 1
                if starts == 2 { followup.fulfill() }
                return ["state": "running"]
            }
            if operation == "sync_cancel" {
                cancelling.fulfill()
                await gate.wait()
                return ["state": "idle"]
            }
            return engine.response(operation)
        }
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        try await session.syncNow()
        let task = Task { try await session.cancelSync() }
        await fulfillment(of: [cancelling], timeout: 2)
        session.scheduleSync()
        XCTAssertEqual(starts, 1)
        await gate.open()
        try await task.value
        await fulfillment(of: [followup], timeout: 2)
        XCTAssertEqual(starts, 2)
    }

    func testFailedDeviceEnrollmentRemovesOrphanedKeyAndClearsWrappingSlot() async throws {
        let engine = SessionTestEngine()
        engine.onPerform = { operation, _ in
            if operation == "biometric_enable" { return ["key": "test-wrapping-key"] }
            return engine.response(operation)
        }
        let keys = SessionTestKeys()
        let session = VaultSession(engine: engine, keyStorage: keys, initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        do { try await session.enableDeviceAuthentication(); XCTFail("Keychain write must fail") } catch {}
        XCTAssertEqual(keys.removalCount, 1)
        XCTAssertTrue(engine.requests.contains { $0.0 == "biometric_disable" })
        XCTAssertTrue(session.isUnlocked)
    }

    func testInitializedStoreIsRecognizedAfterCreateError() async throws {
        let engine = SessionTestEngine()
        engine.onPerform = { operation, _ in
            if operation == "create" { throw VaultFailure.unavailable("creation interrupted after initialization") }
            return engine.response(operation)
        }
        let session = VaultSession(engine: engine, initialize: false)
        do { try await session.prepareToJoin(password: "password"); XCTFail("Create must fail") } catch {}
        XCTAssertTrue(session.isConfigured)
        XCTAssertFalse(session.isUnlocked)
    }
}

@MainActor
private final class SessionTestEngine: VaultEngineAccess {
    var storedEntries: [VaultEntry] = []
    var requests: [(String, [String: Any])] = []
    var onPerform: (@MainActor (String, [String: Any]) async throws -> Any)?
    var failEntryReads = false
    var entryReads = 0

    func response(_ operation: String) -> Any {
        switch operation {
        case "status", "unlock", "create": return ["initialized": true, "locked": false, "vaults": [["id": "vault", "name": "personal"]]] as [String: Any]
        case "passkey_list": return [[String: Any]]()
        case "sync", "sync_status": return ["state": "complete", "results": []] as [String: Any]
        default: return [String: Any]()
        }
    }

    func perform(_ operation: String, _ arguments: [String: Any]) async throws -> Any {
        requests.append((operation, arguments))
        if let onPerform { return try await onPerform(operation, arguments) }
        return response(operation)
    }

    func entries() async throws -> [VaultEntry] {
        entryReads += 1
        if failEntryReads { throw VaultFailure.unavailable("refresh unavailable") }
        return storedEntries
    }

    func publishIdentities(_ entries: [VaultEntry]) async throws {}
    nonisolated func enqueueLock() {}
}

private actor SessionTestGate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        opened = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

private final class SessionTestKeys: DeviceKeyStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var removals = 0
    var removalCount: Int { lock.withLock { removals } }
    func save(_ key: String) throws { throw VaultFailure.unavailable("Keychain unavailable") }
    func remove() throws { lock.withLock { removals += 1 } }
}
