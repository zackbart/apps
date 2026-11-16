import AuthenticationServices
import CryptoKit
import XCTest
@testable import Deadbolt

final class CredentialExchangeConversionTests: XCTestCase {
    private let rfcSHA1 = Data("12345678901234567890".utf8)
    private let rfcSHA256 = Data("12345678901234567890123456789012".utf8)
    private let rfcSHA512 = Data("1234567890123456789012345678901234567890123456789012345678901234".utf8)

    private func item(_ title: String, urls: [String] = ["https://example.com/login"], _ credentials: [CredentialExchangeSource.Credential]) -> CredentialExchangeSource.Item {
        CredentialExchangeSource.Item(title: title, urls: urls, credentials: credentials)
    }

    private func plan(_ items: [CredentialExchangeSource.Item], collections: Int = 0) -> CredentialExchangePlan {
        CredentialExchangeConverter.plan(CredentialExchangeSource.Export(exporter: "Passwords", items: items, collections: collections))
    }

    private func logins(_ plan: CredentialExchangePlan) -> [CredentialExchangeLogin] {
        plan.records.compactMap { if case .login(let login) = $0.content { login } else { nil } }
    }

    private func totp(_ secret: Data, digits: Int = 6, period: Int = 30, algorithm: String = "SHA1", user: String? = nil) -> CredentialExchangeSource.Credential {
        .totp(CredentialExchangeSource.TOTP(secret: secret, period: period, digits: digits, algorithm: algorithm, username: user, issuer: nil))
    }

    private func passkey(_ key: Data, rp: String = "example.com", extensions: [String] = []) -> CredentialExchangeSource.Credential {
        .passkey(CredentialExchangeSource.Passkey(credentialID: Data([0xFB, 0xFF, 0x3E, 0x01]), relyingParty: rp, username: "zoë@example.com", displayName: "Zoë", userHandle: Data([0xFF, 0xEF, 0xBE]), key: key, extensions: extensions))
    }

    func testUnicodeLoginPayloadIsPreservedExactly() throws {
        let result = plan([item("Café ☕︎ 雪", [.login(username: "zoë@例え.jp", password: "pä$$ wörd\n🔑\u{0301}")])])
        let payload = try XCTUnwrap(result.records.first?.payload)
        XCTAssertEqual(payload["type"] as? String, "login")
        XCTAssertEqual(payload["name"] as? String, "Café ☕︎ 雪")
        let fields = try XCTUnwrap(payload["fields"] as? [String: [String: String]])
        XCTAssertEqual(fields["password"], ["type": "secret", "value": "pä$$ wörd\n🔑\u{0301}"])
        XCTAssertEqual(fields["username"], ["type": "text", "value": "zoë@例え.jp"])
        XCTAssertEqual(fields["url"], ["type": "url", "value": "https://example.com/login"])
        XCTAssertNil(fields["notes"])
        XCTAssertNil(fields["otp"])
    }

    func testTOTPConversionMatchesRFC6238Vectors() throws {
        for (secret, algorithm, code) in [(rfcSHA1, "SHA1", "94287082"), (rfcSHA256, "SHA256", "46119246"), (rfcSHA512, "SHA512", "90693936")] {
            let result = plan([item("Bank & Co / Main", [.login(username: "a", password: "b"), totp(secret, digits: 8, algorithm: algorithm)])])
            let uri = try XCTUnwrap(logins(result).first?.otp)
            XCTAssertEqual(try TOTP(uri: uri).code(at: Date(timeIntervalSince1970: 59)), code, algorithm)
            XCTAssertEqual(URLComponents(string: uri)?.queryItems?.first { $0.name == "issuer" }?.value, "Bank & Co / Main")
        }
        XCTAssertEqual(CredentialExchangeFormat.base32(rfcSHA1), "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ")
    }

    func testBase32EncodingRoundTripsEveryLength() {
        for length in 1...41 {
            let bytes = Data((0..<length).map { UInt8(truncatingIfNeeded: $0 &* 37 &+ 11) })
            XCTAssertEqual(TOTP.base32(CredentialExchangeFormat.base32(bytes)), bytes, "length \(length)")
        }
    }

    func testUnsupportedTOTPSettingsAreReportedNotDropped() {
        let result = plan([item("Site", [.login(username: "a", password: "b"), totp(rfcSHA1, digits: 7), totp(rfcSHA1, period: 0), totp(rfcSHA1, algorithm: "MD5"), totp(Data())])])
        XCTAssertEqual(result.excluded.count, 4)
        XCTAssertEqual(logins(result).count, 1)
        XCTAssertTrue(logins(result)[0].otp.isEmpty)
        XCTAssertTrue(result.excluded.allSatisfy { $0.source == "Site" })
    }

    func testMultipleLoginsAndCodesPerItemAreSplitWithoutLoss() throws {
        let result = plan([item("Shared", [
            .login(username: "alice", password: "one"),
            .login(username: "bob", password: "two"),
            totp(rfcSHA1, user: "bob"),
            totp(rfcSHA256, algorithm: "SHA256", user: "alice"),
            totp(rfcSHA512, algorithm: "SHA512", user: "carol"),
            .note("Shared note"),
        ])])
        let rows = logins(result)
        XCTAssertEqual(rows.map(\.username), ["alice", "bob", "carol"])
        XCTAssertEqual(try TOTP(uri: rows[0].otp).secret, rfcSHA256)
        XCTAssertEqual(try TOTP(uri: rows[1].otp).secret, rfcSHA1)
        XCTAssertEqual(try TOTP(uri: rows[2].otp).secret, rfcSHA512)
        XCTAssertTrue(rows[2].password.isEmpty)
        XCTAssertTrue(rows.allSatisfy { $0.notes == "Shared note" })
        XCTAssertTrue(result.excluded.isEmpty)
    }

    func testSingleLoginReceivesCodeEvenWithDifferentAccountLabel() {
        let result = plan([item("Mail", [.login(username: "me", password: "p"), totp(rfcSHA1, user: "me@example.com")])])
        XCTAssertEqual(logins(result).count, 1)
        XCTAssertFalse(logins(result)[0].otp.isEmpty)
    }

    func testPasskeyPayloadUsesStandardBase64AndPKCS8() throws {
        let key = P256.Signing.PrivateKey().derRepresentation
        let result = plan([item("Example", [passkey(key)])])
        XCTAssertEqual(result.passkeyCount, 1)
        let payload = try XCTUnwrap(result.records.first?.payload)
        XCTAssertEqual(payload["type"] as? String, "passkey")
        XCTAssertEqual(payload["rp_id"] as? String, "example.com")
        XCTAssertEqual(payload["username"] as? String, "zoë@example.com")
        XCTAssertEqual(payload["display_name"] as? String, "Zoë")
        XCTAssertEqual(payload["credential_id"] as? String, "+/8+AQ==")
        XCTAssertEqual(payload["user_handle"] as? String, "/+++")
        XCTAssertEqual(payload["private_key"] as? String, key.base64EncodedString())
        XCTAssertEqual(try P256.Signing.PrivateKey(derRepresentation: Data(base64Encoded: payload["private_key"] as! String)!).rawRepresentation.count, 32)
    }

    func testUnsupportedPasskeysAreReportedNotStripped() {
        let p256 = P256.Signing.PrivateKey().derRepresentation
        let ed25519 = Data([0x30, 0x2E, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06, 0x03, 0x2B, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20] + [UInt8](repeating: 7, count: 32))
        let result = plan([item("Keys", [
            passkey(p256, extensions: ["the PRF (hmac-secret) extension"]),
            passkey(ed25519),
            passkey(Data([0x30, 0x00])),
            passkey(p256, rp: ""),
            passkey(p256, rp: "ok.example"),
        ])])
        XCTAssertEqual(result.passkeyCount, 1)
        XCTAssertEqual(result.excluded.count, 4)
        XCTAssertTrue(result.excluded[0].message.contains("hmac-secret"))
        XCTAssertTrue(result.excluded[1].message.contains("key type"))
        XCTAssertFalse(CredentialExchangeFormat.isP256PKCS8(P256.Signing.PrivateKey().rawRepresentation))
        XCTAssertFalse(CredentialExchangeFormat.isP256PKCS8(P384.Signing.PrivateKey().derRepresentation))
    }

    func testUnsupportedCredentialsAndMetadataAreReported() throws {
        var source = item("Everything", urls: ["https://primary.example", "https://second.example", "ftp://files.example"], [.login(username: "u", password: "p"), .unsupported("A payment card"), .unsupported("An SSH key")])
        source.tags = ["work", "finance"]
        source.androidApps = ["Example (com.example.app)"]
        source.favorite = true
        source.unsupportedMetadata = ["Sharing settings on this item aren’t kept."]
        let result = plan([source], collections: 2)
        let login = try XCTUnwrap(logins(result).first)
        XCTAssertEqual(login.url, "https://primary.example")
        XCTAssertTrue(login.notes.contains("https://second.example\nftp://files.example"))
        XCTAssertTrue(login.notes.contains("Example (com.example.app)"))
        XCTAssertTrue(login.notes.contains("Tags: work, finance"))
        XCTAssertEqual(result.excluded.map(\.message), ["A payment card isn’t supported by Deadbolt and wasn’t imported.", "An SSH key isn’t supported by Deadbolt and wasn’t imported."])
        XCTAssertEqual(result.notices.count, 3)
    }

    func testMetadataOnPasskeyOnlyItemIsReported() {
        var source = item("Key only", urls: ["https://a.example", "https://b.example"], [passkey(P256.Signing.PrivateKey().derRepresentation)])
        source.tags = ["t"]
        let result = plan([source])
        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.notices.count, 1)
    }

    func testNoteOnlyItemsImportAsNotes() throws {
        let result = plan([item("Door code", urls: [], [.note("1234")])])
        XCTAssertEqual(try XCTUnwrap(logins(result).first).notes, "1234")
        XCTAssertTrue(result.excluded.isEmpty)
    }

    func testIdenticalSourceItemsAreAllSent() {
        let duplicate = item("Same", [.login(username: "a", password: "b")])
        let result = plan([duplicate, duplicate, duplicate])
        XCTAssertEqual(result.records.count, 3)
        XCTAssertEqual(Set(result.records.map(\.id)).count, 3)
        XCTAssertEqual(result.sourceItems, 3)
    }

    func testAppleExportAdapterMapsEveryCredential() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Credential Exchange requires iOS 26") }
        let key = P256.Signing.PrivateKey().derRepresentation
        let item = ASImportableItem(id: Data([1]), created: Date(), lastModified: Date(), title: "Example", favorite: true,
                                    scope: ASImportableCredentialScope(urls: [URL(string: "https://example.com")!, URL(string: "https://alt.example.com")!]),
                                    credentials: [
                                        .basicAuthentication(.init(userName: .init(id: nil, fieldType: .string, value: "zoë"), password: .init(id: nil, fieldType: .concealedString, value: "sécret"))),
                                        .totp(.init(secret: rfcSHA1, period: 30, digits: 8, userName: "zoë", algorithm: .sha1)),
                                        .passkey(.init(credentialID: Data([1, 2]), relyingPartyIdentifier: "example.com", userName: "zoë", userDisplayName: "Zoë", userHandle: Data([3]), key: key)),
                                        .creditCard(.init(number: nil, fullName: nil, cardType: nil, verificationNumber: nil, pin: nil, expiryDate: nil, validFrom: nil)),
                                    ], tags: ["tag"])
        let collection = ASImportableCollection(id: Data([9]), created: nil, lastModified: nil, title: "Folder", items: [], subcollections: [ASImportableCollection(id: Data([10]), created: nil, lastModified: nil, title: "Inner", items: [])])
        let data = ASExportedCredentialData(accounts: [ASImportableAccount(id: Data([0]), userName: "", email: "", collections: [collection], items: [item])], formatVersion: .v1, exporterRelyingPartyIdentifier: "apple.com", exporterDisplayName: "Passwords", timestamp: Date())
        let result = CredentialExchangeConverter.plan(CredentialExchangeSource.Export(data))
        XCTAssertEqual(result.exporter, "Passwords")
        XCTAssertEqual(result.loginCount, 1)
        XCTAssertEqual(result.passkeyCount, 1)
        XCTAssertEqual(result.excluded.count, 1)
        let login = try XCTUnwrap(logins(result).first)
        XCTAssertEqual(login.password, "sécret")
        XCTAssertEqual(try TOTP(uri: login.otp).code(at: Date(timeIntervalSince1970: 59)), "94287082")
        XCTAssertTrue(login.notes.contains("https://alt.example.com"))
        XCTAssertTrue(result.notices.contains { $0.message.contains("Favorites (1)") })
        XCTAssertTrue(result.notices.contains { $0.message.contains("(2)") })
    }

    func testAppleFIDO2ExtensionsAreRejected() throws {
        guard #available(iOS 26.4, *) else { throw XCTSkip("FIDO2 extensions require iOS 26.4") }
        let key = P256.Signing.PrivateKey().derRepresentation
        let extensions = ASImportableFIDO2Extensions(hmacCredentials: ASImportableFIDO2HMACCredential(algorithm: .sha256, credentialWithUV: Data(repeating: 1, count: 32), credentialWithoutUV: Data(repeating: 2, count: 32)), largeBlob: ASImportableFIDO2LargeBlob(uncompressedSize: 1, data: Data([1])))
        let credential = ASImportableCredential.passkey(.init(credentialID: Data([1]), relyingPartyIdentifier: "example.com", userName: "u", userDisplayName: "U", userHandle: Data([2]), key: key, fido2Extensions: extensions))
        let item = ASImportableItem(id: Data([1]), title: "Example", credentials: [credential])
        let result = CredentialExchangeConverter.plan(CredentialExchangeSource.Export(exporter: "Passwords", items: [CredentialExchangeSource.Item(item)]))
        XCTAssertEqual(result.passkeyCount, 0)
        XCTAssertEqual(result.excluded.count, 1)
        XCTAssertTrue(result.excluded[0].message.contains("hmac-secret"))
        XCTAssertTrue(result.excluded[0].message.contains("large blob"))
    }
}

@MainActor
final class CredentialExchangeLifecycleTests: XCTestCase {
    nonisolated private static func record(_ id: Int, name: String = "Example") -> CredentialExchangeRecord {
        CredentialExchangeRecord(id: id, source: name, content: .login(CredentialExchangeLogin(name: name, username: "alice", password: "secret")))
    }

    nonisolated private static func plan(_ name: String, records: Int = 2) -> CredentialExchangePlan {
        CredentialExchangePlan(exporter: "Passwords", sourceItems: records, records: (0..<records).map { Self.record($0, name: name) }, excluded: [], notices: [])
    }

    private func eventually(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<500 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Condition not met", file: file, line: line)
    }

    func testSessionSendsOneCredentialExchangeBatch() async throws {
        let engine = ExchangeTestEngine()
        engine.onPerform = { operation, arguments in
            if operation == "credential_exchange_import" {
                XCTAssertEqual(arguments["vault_id"] as? String, "vault")
                XCTAssertEqual((arguments["items"] as? [[String: Any]])?.count, 3)
                return ["ids": ["a", "b"], "imported": 2, "skipped": 1] as [String: Any]
            }
            return engine.response(operation)
        }
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        let summary = try await session.importCredentialExchange([Self.record(0), Self.record(1), Self.record(2)], vaultID: "vault")
        XCTAssertEqual(summary, VaultImportSummary(imported: 2, skipped: 1))
        XCTAssertEqual(engine.requests.filter { $0.0 == "credential_exchange_import" }.count, 1)
        XCTAssertFalse(engine.requests.contains { $0.0 == "import" || $0.0 == "save" })
    }

    func testSessionRejectsUnconfirmedCounts() async throws {
        let engine = ExchangeTestEngine()
        engine.onPerform = { operation, _ in
            if operation == "credential_exchange_import" { return ["imported": 1, "skipped": 0] }
            return engine.response(operation)
        }
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        do { _ = try await session.importCredentialExchange([Self.record(0), Self.record(1)], vaultID: "vault"); XCTFail("Mismatched counts must fail") } catch {}
        do { _ = try await session.importCredentialExchange([Self.record(0)], vaultID: "missing"); XCTFail("Unknown vault must fail") } catch {}
    }

    func testTokenWaitsForUnlockBeforeReceivingSecrets() async throws {
        let session = VaultSession(engine: ExchangeTestEngine(), initialize: false)
        let fetches = FetchCounter()
        let exchange = CredentialExchangeCoordinator { _ in await fetches.increment(); return CredentialExchangePlan(exporter: "Passwords", sourceItems: 1, records: [CredentialExchangeRecord(id: 0, source: "A", content: .login(CredentialExchangeLogin(name: "A", password: "p")))], excluded: [], notices: []) }
        exchange.receive(UUID(), session: session)
        XCTAssertEqual(exchange.phase, .waitingForVault)
        try await Task.sleep(for: .milliseconds(50))
        let early = await fetches.value
        XCTAssertEqual(early, 0)
        exchange.protect()
        XCTAssertEqual(exchange.phase, .waitingForVault)
        try await session.unlock(password: "password")
        defer { session.lock() }
        exchange.resume(session: session)
        await eventually { exchange.phase == .review }
        let fetched = await fetches.value
        XCTAssertEqual(fetched, 1)
        XCTAssertEqual(exchange.destinationID, "vault")
        XCTAssertEqual(exchange.selection, [0])
        XCTAssertTrue(exchange.canImport(into: session.vaults))
    }

    func testLockClearsReviewedSecrets() async throws {
        let session = VaultSession(engine: ExchangeTestEngine(), initialize: false)
        try await session.unlock(password: "password")
        let exchange = CredentialExchangeCoordinator { _ in Self.plan("Secret") }
        exchange.receive(UUID(), session: session)
        await eventually { exchange.phase == .review }
        session.lock()
        exchange.protect()
        XCTAssertNil(exchange.plan)
        XCTAssertTrue(exchange.selection.isEmpty)
        guard case .failed = exchange.phase else { return XCTFail("Lock must end the transfer") }
    }

    func testStaleFetchCannotReplaceNewerTransfer() async throws {
        let session = VaultSession(engine: ExchangeTestEngine(), initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        let gate = ExchangeGate()
        let first = UUID()
        let exchange = CredentialExchangeCoordinator { token in
            if token == first {
                await gate.wait()
                return Self.plan("Stale", records: 5)
            }
            return Self.plan("Fresh", records: 1)
        }
        exchange.receive(first, session: session)
        XCTAssertEqual(exchange.phase, .loading)
        exchange.receive(UUID(), session: session)
        await eventually { exchange.phase == .review }
        await gate.open()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(exchange.plan?.records.first?.title, "Fresh")
        XCTAssertEqual(exchange.plan?.records.count, 1)
    }

    func testCancelledFetchResultIsDiscarded() async throws {
        let session = VaultSession(engine: ExchangeTestEngine(), initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        let gate = ExchangeGate()
        let exchange = CredentialExchangeCoordinator { _ in await gate.wait(); return Self.plan("Late") }
        exchange.receive(UUID(), session: session)
        exchange.cancel(session: session)
        await gate.open()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(exchange.phase, .idle)
        XCTAssertNil(exchange.plan)
    }

    func testLockDuringImportIgnoresLateResultAndKeepsVaultLocked() async throws {
        let engine = ExchangeTestEngine()
        let gate = ExchangeGate()
        let started = expectation(description: "import started")
        engine.onPerform = { operation, _ in
            if operation == "credential_exchange_import" {
                started.fulfill()
                await gate.wait()
                return ["imported": 2, "skipped": 0]
            }
            return engine.response(operation)
        }
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        let exchange = CredentialExchangeCoordinator { _ in Self.plan("Batch") }
        exchange.receive(UUID(), session: session)
        await eventually { exchange.phase == .review }
        exchange.importSelected(session: session)
        await fulfillment(of: [started], timeout: 2)
        let next = UUID()
        exchange.receive(next, session: session)
        session.lock()
        exchange.protect()
        await gate.open()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(session.isUnlocked)
        XCTAssertTrue(session.entries.isEmpty)
        XCTAssertNil(exchange.plan)
        XCTAssertEqual(exchange.phase, .waitingForVault)
    }

    func testFailedImportReturnsToReviewWithoutLosingSelection() async throws {
        let engine = ExchangeTestEngine()
        engine.onPerform = { operation, _ in
            if operation == "credential_exchange_import" { throw VaultFailure.unavailable("Passkey conflicts with an existing passkey.") }
            return engine.response(operation)
        }
        let session = VaultSession(engine: engine, initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        let exchange = CredentialExchangeCoordinator { _ in Self.plan("Batch", records: 3) }
        exchange.receive(UUID(), session: session)
        await eventually { exchange.phase == .review }
        exchange.selection.remove(1)
        exchange.importSelected(session: session)
        await eventually { exchange.error != nil }
        XCTAssertEqual(exchange.phase, .review)
        XCTAssertEqual(exchange.selection, [0, 2])
        XCTAssertTrue(exchange.error?.contains("items already saved will be skipped") == true)
    }

    func testExclusionsRequireAcknowledgement() async throws {
        let session = VaultSession(engine: ExchangeTestEngine(), initialize: false)
        try await session.unlock(password: "password")
        defer { session.lock() }
        let exchange = CredentialExchangeCoordinator { _ in
            CredentialExchangePlan(exporter: "Passwords", sourceItems: 2, records: [Self.record(0)], excluded: [CredentialExchangeIssue(id: 0, source: "Card", message: "A payment card isn’t supported by Deadbolt and wasn’t imported.")], notices: [])
        }
        exchange.receive(UUID(), session: session)
        await eventually { exchange.phase == .review }
        XCTAssertFalse(exchange.canImport(into: session.vaults))
        exchange.acknowledgedExclusions = true
        XCTAssertTrue(exchange.canImport(into: session.vaults))
        exchange.selectAll(false)
        XCTAssertFalse(exchange.canImport(into: session.vaults))
    }

    func testActivityTokenExtraction() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Credential Exchange requires iOS 26") }
        XCTAssertEqual(CredentialExchangeCoordinator.activityType, ASCredentialExchangeActivity)
        let token = UUID()
        let activity = NSUserActivity(activityType: ASCredentialExchangeActivity)
        activity.userInfo = [ASCredentialImportToken: token]
        XCTAssertEqual(CredentialExchangeCoordinator.token(from: activity), token)
        XCTAssertNil(CredentialExchangeCoordinator.token(from: NSUserActivity(activityType: "other")))
    }
}

@MainActor
private final class ExchangeTestEngine: VaultEngineAccess {
    var requests: [(String, [String: Any])] = []
    var onPerform: (@MainActor (String, [String: Any]) async throws -> Any)?

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

    func entries() async throws -> [VaultEntry] { [] }
    func publishIdentities(_ entries: [VaultEntry]) async throws {}
    nonisolated func enqueueLock() {}
}

private actor ExchangeGate {
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

private actor FetchCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}
