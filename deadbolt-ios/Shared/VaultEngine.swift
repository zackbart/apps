import Foundation
import AuthenticationServices


final class VaultEngine: VaultEngineAccess, @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.zackbart.deadbolt.engine", qos: .userInitiated)
    private let directory: URL
    private let stateLock = NSLock()
    private var epoch = 0
    private var identityTask: Task<Void, Error>?

    init() throws {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.dev.zackbart.deadbolt") else {
            throw VaultFailure.unavailable("The shared vault container is unavailable. Check app signing and App Groups.")
        }
        directory = root.appendingPathComponent("Vault", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        var excluded = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
    }

    private func request(_ op: String, _ arguments: [String: Any], expectedEpoch: Int, admission: RequestAdmission) throws -> Any {
        try queue.sync {
            guard stateLock.withLock({ epoch == expectedEpoch }), admission.begin() else { throw CancellationError() }
            var request = arguments
            request["op"] = op
            request["data_dir"] = directory.path
            let data = try JSONSerialization.data(withJSONObject: request)
            guard let json = String(data: data, encoding: .utf8), let pointer = json.withCString({ deadbolt_request($0) }) else {
                throw VaultFailure.unavailable("The vault engine could not respond.")
            }
            defer { deadbolt_free(pointer) }
            let response = Data(bytes: pointer, count: strlen(pointer))
            guard let object = try JSONSerialization.jsonObject(with: response) as? [String: Any], object["ok"] as? Bool == true else {
                let decoded = try? JSONSerialization.jsonObject(with: response) as? [String: Any]
                let detail = decoded?["error"] as? String ?? "Vault operation failed."
                throw VaultFailure.unavailable(detail)
            }
            return object["result"] ?? NSNull()
        }
    }

    func enqueueLock() {
        stateLock.withLock { epoch += 1 }
        directory.path.withCString { deadbolt_cancel($0) }
        queue.async { _ = try? self.requestOnQueue("lock") }
    }

    private func requestOnQueue(_ op: String) throws -> Any {
        let request: [String: Any] = ["op": op, "data_dir": directory.path]
        let data = try JSONSerialization.data(withJSONObject: request)
        guard let json = String(data: data, encoding: .utf8), let pointer = json.withCString({ deadbolt_request($0) }) else { return NSNull() }
        defer { deadbolt_free(pointer) }
        return NSNull()
    }

    func perform(_ op: String, _ arguments: [String: Any] = [:]) async throws -> Any {
        try Task.checkCancellation()
        let current = stateLock.withLock { epoch }
        let admission = RequestAdmission()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) { try self.request(op, arguments, expectedEpoch: current, admission: admission) }.value
        } onCancel: { admission.cancel() }
    }

    func entries() async throws -> [VaultEntry] {
        guard let rows = try await perform("list") as? [[String: Any]] else { throw VaultFailure.unavailable("Invalid vault response.") }
        return rows.filter { $0["type"] as? String == "login" }.compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            let fields = row["fields"] as? [String: [String: Any]] ?? [:]
            func field(_ name: String) -> String { fields[name]?["value"] as? String ?? "" }
            var entry = VaultEntry(id: id, title: row["name"] as? String ?? "Login", username: field("username"), password: field("password"), url: field("url"), notes: field("notes"), vaultID: row["vault_id"] as? String, totp: field("otp"))
            entry.extraFields = fields.mapValues { value in value.compactMapValues { $0 as? String } }
            return entry
        }
    }

    func publishIdentities(_ entries: [VaultEntry]) async throws {
        let task = stateLock.withLock {
            let previous = identityTask
            let current = epoch
            let task = Task { [self] in
                _ = try? await previous?.value
                guard stateLock.withLock({ epoch == current }) else { throw CancellationError() }
                try await replaceIdentities(expectedEpoch: current)
            }
            identityTask = task
            return task
        }
        try await task.value
    }

    private func replaceIdentities(expectedEpoch: Int) async throws {
        let entries = try await entries()
        var identities: [any ASCredentialIdentity] = entries.compactMap { entry -> ASPasswordCredentialIdentity? in
            guard let host = CredentialDomain.host(entry.url) else { return nil }
            return ASPasswordCredentialIdentity(serviceIdentifier: ASCredentialServiceIdentifier(identifier: host, type: .domain), user: entry.username, recordIdentifier: entry.id)
        }
        if let passkeys = try await perform("passkey_list") as? [[String: Any]] {
            identities += passkeys.compactMap { record -> ASPasskeyCredentialIdentity? in
                guard let rp = record["rp_id"] as? String, let user = record["username"] as? String,
                      let credential = record["credential_id"] as? String, let credentialID = Data(base64Encoded: credential),
                      let handle = record["user_handle"] as? String, let userHandle = Data(base64Encoded: handle) else { return nil }
                return ASPasskeyCredentialIdentity(relyingPartyIdentifier: rp, userName: user, credentialID: credentialID, userHandle: userHandle, recordIdentifier: record["id"] as? String)
            }
        }
        guard stateLock.withLock({ epoch == expectedEpoch }) else { throw CancellationError() }
        try await ASCredentialIdentityStore.shared.replaceCredentialIdentities(identities)
    }
}
