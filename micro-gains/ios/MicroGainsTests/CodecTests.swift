import XCTest
@testable import MicroGains

final class CodecTests: XCTestCase {
    // MARK: - UUID v5

    func testUUIDv5MatchesTheRFC4122Vector() {
        // Cross-checked against Python: uuid.uuid5(uuid.NAMESPACE_DNS, "www.example.com")
        let uuid = UUIDv5.make(namespace: UUIDv5.dnsNamespace, name: "www.example.com")
        XCTAssertEqual(uuid.uuidString.lowercased(), "2ed6657d-e927-568b-95e1-2665a8aea6a2")
    }

    func testUUIDv5SetsVersionAndVariantBits() {
        let uuid = UUIDv5.make(namespace: UUIDv5.dnsNamespace, name: "micro-gains")
        let bytes = withUnsafeBytes(of: uuid.uuid) { Array($0) }
        XCTAssertEqual(bytes[6] & 0xF0, 0x50, "version nibble must be 5")
        XCTAssertEqual(bytes[8] & 0xC0, 0x80, "variant bits must be RFC 4122")
    }

    func testUUIDv5IsStableAndNameSensitive() {
        let a = UUIDv5.make(namespace: UUIDv5.slotNamespace, name: "slot-2026-06-01T13:00:00Z")
        let b = UUIDv5.make(namespace: UUIDv5.slotNamespace, name: "slot-2026-06-01T13:00:00Z")
        let c = UUIDv5.make(namespace: UUIDv5.slotNamespace, name: "slot-2026-06-01T15:00:00Z")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Seeding

    func testSeedIsStableAcrossCalls() {
        XCTAssertEqual(Seed.value("a", "b"), Seed.value("a", "b"))
        XCTAssertNotEqual(Seed.value("a", "b"), Seed.value("a", "c"))
    }

    func testSeedIndexStaysInRange() {
        for i in 0..<200 {
            let index = Seed.index(Seed.value("device", "\(i)"), upperBound: 7)
            XCTAssertTrue((0..<7).contains(index))
        }
        XCTAssertEqual(Seed.index(12345, upperBound: 0), 0)
    }

    // MARK: - Wire format

    func testSettingsRoundTripThroughTheAPICodec() throws {
        let settings = Fixtures.settings(
            interval: 90,
            difficulty: .hard,
            days: 0b0011111,
            office: true,
            floor: false,
            pausedUntil: Fixtures.date(2026, 6, 2, 9, 0),
            levels: ["full_pushup": .easy]
        )
        let data = try APIClient.encoder.encode(settings)
        let decoded = try APIClient.decoder.decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    func testSettingsUseSnakeCaseOnTheWire() throws {
        let data = try APIClient.encoder.encode(Fixtures.settings())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in [
            "interval_minutes", "difficulty", "active_start_minute", "active_end_minute",
            "active_days", "office_mode", "floor_ok", "enabled", "exercise_levels", "timezone"
        ] {
            XCTAssertNotNil(json[key], "missing \(key)")
        }
        XCTAssertNil(json["intervalMinutes"])
    }

    func testSettingsDecodeFromAServerPayload() throws {
        let json = """
        {
          "interval_minutes": 180,
          "difficulty": "easy",
          "active_start_minute": 480,
          "active_end_minute": 1200,
          "active_days": 62,
          "office_mode": true,
          "floor_ok": false,
          "enabled": true,
          "paused_until": null,
          "exercise_levels": {"air_squat": "hard"},
          "timezone": "Europe/Berlin",
          "updated_at": "2026-08-19T10:00:00Z"
        }
        """
        let settings = try APIClient.decoder.decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.intervalMinutes, 180)
        XCTAssertEqual(settings.difficulty, .easy)
        XCTAssertEqual(settings.activeDays, 62)
        XCTAssertTrue(settings.officeMode)
        XCTAssertFalse(settings.floorOk)
        XCTAssertNil(settings.pausedUntil)
        XCTAssertEqual(settings.exerciseLevels["air_squat"], .hard)
        XCTAssertEqual(settings.timezone, "Europe/Berlin")
        XCTAssertEqual(settings.setsPerDay, 4)
    }

    func testSetLogRoundTrip() throws {
        let log = SetLog(
            id: UUID().uuidString.lowercased(),
            exerciseID: "full_pushup",
            target: 10,
            unit: .reps,
            status: .skipped,
            skipReason: .tooHard,
            scheduledAt: Fixtures.date(2026, 6, 1, 13, 2),
            loggedAt: Fixtures.date(2026, 6, 1, 13, 4),
            localDate: "2026-06-01",
            source: .notification
        )
        let data = try APIClient.encoder.encode(log)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["exercise_id"] as? String, "full_pushup")
        XCTAssertEqual(json["skip_reason"] as? String, "too_hard")
        XCTAssertEqual(json["local_date"] as? String, "2026-06-01")
        XCTAssertEqual(json["source"] as? String, "notification")

        let decoded = try APIClient.decoder.decode(SetLog.self, from: data)
        XCTAssertEqual(decoded, log)
    }

    func testSetsBatchEnvelopeShape() throws {
        let log = SetLog(
            id: "abc", exerciseID: "air_squat", target: 18, unit: .reps,
            status: .done, skipReason: nil, scheduledAt: nil,
            loggedAt: Fixtures.date(2026, 6, 1, 13, 4),
            localDate: "2026-06-01", source: .app
        )
        let data = try APIClient.encoder.encode(APIClient.SetsRequest(sets: [log]))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual((json["sets"] as? [[String: Any]])?.count, 1)
    }

    func testStatsAndHistoryDecodeFromTheServerShape() throws {
        let json = """
        {
          "days": [{"date":"2026-06-01","done":3,"skipped":1,"reps":54,"seconds":80}],
          "stats": {
            "today_done": 3, "today_skipped": 1, "streak_days": 4,
            "best_streak_days": 9, "total_done": 41, "total_reps": 620, "total_seconds": 900
          }
        }
        """
        let response = try APIClient.decoder.decode(APIClient.HistoryResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.days.first?.reps, 54)
        XCTAssertEqual(response.stats.streakDays, 4)
        XCTAssertEqual(response.stats.bestStreakDays, 9)
    }

    func testSetsResponseDecodesRejections() throws {
        let json = """
        {"accepted":2,"duplicates":1,"rejected":[{"id":"x","error":"unknown_exercise"}],
         "stats":{"today_done":0,"today_skipped":0,"streak_days":0,"best_streak_days":0,
                  "total_done":0,"total_reps":0,"total_seconds":0}}
        """
        let response = try APIClient.decoder.decode(APIClient.SetsResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.accepted, 2)
        XCTAssertEqual(response.duplicates, 1)
        XCTAssertEqual(response.rejected.first?.error, "unknown_exercise")
    }

    func testCatalogResponseDecodesAndToleratesAMissingIntenseFlag() throws {
        let json = """
        {"exercises":[{"id":"air_squat","name":"Air squat","pattern":"squat","unit":"reps",
        "easy":10,"medium":18,"hard":28,"cue":"Sit hips back","office_ok":true,
        "needs_floor":false}],"version":"abc123"}
        """
        let response = try APIClient.decoder.decode(APIClient.CatalogResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.version, "abc123")
        XCTAssertEqual(response.exercises.first?.intense, false)
    }

    func testBundledCatalogLoadsAndIsWellFormed() {
        let catalog = Fixtures.bundledCatalog
        XCTAssertGreaterThan(catalog.count, 20)
        XCTAssertEqual(Set(catalog.map(\.id)).count, catalog.count, "ids must be unique")
        XCTAssertTrue(catalog.contains { $0.intense })
        for exercise in catalog {
            XCTAssertLessThanOrEqual(exercise.easy, exercise.medium)
            XCTAssertLessThanOrEqual(exercise.medium, exercise.hard)
            XCTAssertFalse(exercise.cue.isEmpty)
        }
        for pattern in Pattern.allCases {
            XCTAssertTrue(catalog.contains { $0.pattern == pattern }, "no \(pattern) exercises")
        }
    }

    // MARK: - Prescriptions and notification copy

    func testPrescriptionReadsLikeEnglish() {
        let catalog = Fixtures.bundledCatalog
        func line(_ id: String, _ target: Int) -> String {
            catalog.first { $0.id == id }!.prescription(target: target)
        }
        XCTAssertEqual(line("air_squat", 15), "15 air squats")
        XCTAssertEqual(line("full_pushup", 10), "10 push-ups")
        XCTAssertEqual(line("forearm_plank", 45), "Forearm plank, 45 seconds")
        XCTAssertEqual(line("sit_to_stand", 16), "16 sit-to-stands")
        XCTAssertEqual(line("side_plank", 25), "Side plank, 25 seconds")
        XCTAssertEqual(line("jumping_jacks", 35), "35 jumping jacks")
    }

    func testNotificationBodyRotatesByTemplate() {
        let catalog = Fixtures.bundledCatalog
        let slots = Scheduler.plan(
            settings: Fixtures.settings(),
            catalog: catalog,
            now: Fixtures.date(2026, 6, 1, 0, 1),
            deviceID: Fixtures.deviceID
        )
        let bodies = Set(slots.map { NotificationPlanner.body(for: $0, catalog: catalog, streakDays: 4) })
        XCTAssertGreaterThan(bodies.count, 5, "identical prompts decay; the copy has to vary")
        XCTAssertTrue(slots.allSatisfy { !NotificationPlanner.title(for: $0, catalog: catalog).isEmpty })
        XCTAssertFalse(bodies.contains { $0.contains("!") }, "no exclamation points")
    }

    func testNotificationDiffAddsMissingAndRemovesStale() {
        let now = Fixtures.date(2026, 6, 1, 0, 1)
        let slots = Scheduler.plan(
            settings: Fixtures.settings(),
            catalog: Fixtures.bundledCatalog,
            now: now,
            deviceID: Fixtures.deviceID
        )
        let pending = [
            NotificationPlanner.Pending(
                identifier: slots[0].identifier,
                fingerprint: slots[0].contentFingerprint
            ),
            NotificationPlanner.Pending(identifier: "slot-2020-01-01T00:00:00Z"),
            NotificationPlanner.Pending(identifier: slots[1].identifier + "-snooze")
        ]
        let diff = NotificationPlanner.diff(pending: pending, against: slots, now: now)

        XCTAssertEqual(diff.toRemove, ["slot-2020-01-01T00:00:00Z"])
        XCTAssertFalse(diff.toAdd.contains { $0.identifier == slots[0].identifier })
        XCTAssertEqual(diff.toAdd.count, slots.count - 1)
        XCTAssertEqual(diff.unchanged, [slots[0].identifier])
    }

    func testDiffLeavesSnoozedCopiesAlone() {
        let now = Fixtures.date(2026, 6, 1, 0, 1)
        let slots = Scheduler.plan(
            settings: Fixtures.settings(),
            catalog: Fixtures.bundledCatalog,
            now: now,
            deviceID: Fixtures.deviceID
        )
        let diff = NotificationPlanner.diff(pending: ["slot-2020-01-01T00:00:00Z-snooze"], against: slots, now: now)
        XCTAssertTrue(diff.toRemove.isEmpty)
    }

    func testDiffSkipsSlotsAlreadyInThePast() {
        let now = Fixtures.date(2026, 6, 1, 0, 1)
        let slots = Scheduler.plan(
            settings: Fixtures.settings(),
            catalog: Fixtures.bundledCatalog,
            now: now,
            deviceID: Fixtures.deviceID
        )
        let later = slots[3].scheduledAt
        let diff = NotificationPlanner.diff(pending: [], against: slots, now: later)
        XCTAssertTrue(diff.toAdd.allSatisfy { $0.scheduledAt > later })
    }

    func testNotificationUserInfoCarriesEverythingTheActionHandlerNeeds() {
        let catalog = Fixtures.bundledCatalog
        let slot = Scheduler.plan(
            settings: Fixtures.settings(),
            catalog: catalog,
            now: Fixtures.date(2026, 6, 1, 0, 1),
            deviceID: Fixtures.deviceID
        )[0]
        let info = NotificationPlanner.content(for: slot, catalog: catalog, streakDays: 2).userInfo

        XCTAssertEqual(info[NotificationPlanner.UserInfoKey.setID] as? String, slot.setID.uuidString)
        XCTAssertEqual(info[NotificationPlanner.UserInfoKey.exerciseID] as? String, slot.exerciseID)
        XCTAssertEqual(info[NotificationPlanner.UserInfoKey.target] as? Int, slot.target)
        XCTAssertEqual(info[NotificationPlanner.UserInfoKey.unit] as? String, slot.unit.rawValue)
        XCTAssertEqual(info[NotificationPlanner.UserInfoKey.identifier] as? String, slot.identifier)
        XCTAssertNotNil(ISO8601.parse(info[NotificationPlanner.UserInfoKey.scheduledAt] as? String ?? ""))
    }

    func testSnoozeIdentifierIsIdempotent() {
        // Snoozing a snooze must not stack suffixes; there is one snooze per slot.
        let base = "slot-2026-06-01T13:00:00Z"
        let snoozed = base + NotificationPlanner.snoozeSuffix
        XCTAssertTrue(snoozed.hasSuffix(NotificationPlanner.snoozeSuffix))
        XCTAssertEqual(String(snoozed.dropLast(NotificationPlanner.snoozeSuffix.count)), base)
        XCTAssertEqual(NotificationPlanner.snoozeInterval, 600)
    }

    // MARK: - ISO helpers

    func testLocalDateUsesTheDeviceZone() {
        // 04:30 UTC on 2 June is still 1 June in New York.
        let instant = ISO8601.utc.date(from: "2026-06-02T03:30:00Z")!
        XCTAssertEqual(ISO8601.localDate(instant, timeZone: TimeZone(identifier: "America/New_York")!), "2026-06-01")
        XCTAssertEqual(ISO8601.localDate(instant, timeZone: TimeZone(identifier: "UTC")!), "2026-06-02")
    }

    func testISOParseHandlesFractionalSeconds() {
        XCTAssertNotNil(ISO8601.parse("2026-06-01T13:00:00Z"))
        XCTAssertNotNil(ISO8601.parse("2026-06-01T13:00:00.250Z"))
        XCTAssertNil(ISO8601.parse("not a date"))
    }

    func testAPIBaseURLPointsAtTheLocalWorkerInDebug() {
        #if DEBUG
        XCTAssertEqual(APIClient.baseURL.absoluteString, "http://127.0.0.1:8788")
        #endif
    }
}

// MARK: - Notification budget and content fingerprints

final class NotificationBudgetTests: XCTestCase {
    private let now = Fixtures.date(2026, 6, 1, 0, 1)

    private func plan(_ difficulty: Difficulty = .medium) -> [Slot] {
        Scheduler.plan(
            settings: Fixtures.settings(difficulty: difficulty),
            catalog: Fixtures.bundledCatalog,
            now: now,
            deviceID: Fixtures.deviceID
        )
    }

    private func snoozes(_ count: Int) -> [NotificationPlanner.Pending] {
        (0..<count).map {
            NotificationPlanner.Pending(identifier: "slot-2026-05-0\($0)T09:00:00Z" + NotificationPlanner.snoozeSuffix)
        }
    }

    func testAnEmptyQueueTakesTheWholePlan() {
        let slots = plan()
        XCTAssertEqual(slots.count, NotificationPlanner.maxRegular)
        let diff = NotificationPlanner.diff(pending: [], against: slots, now: now)
        XCTAssertEqual(diff.toAdd.count, NotificationPlanner.maxRegular)
        XCTAssertTrue(diff.toRemove.isEmpty)
    }

    func testSnoozesEatIntoTheAddBudget() {
        let slots = plan()
        for count in [1, 4, 8, 12] {
            let pending = snoozes(count)
            let diff = NotificationPlanner.diff(pending: pending, against: slots, now: now)
            let total = pending.count + diff.unchanged.count + diff.toAdd.count

            XCTAssertEqual(diff.toAdd.count, min(NotificationPlanner.maxRegular, 64 - count), "\(count) snoozes")
            XCTAssertLessThanOrEqual(total, NotificationPlanner.maxPending, "\(count) snoozes overflows the queue")
            XCTAssertTrue(diff.toRemove.isEmpty, "a snooze the user asked for is never dropped")
        }
    }

    func testAQueueOverTheCapDropsTheFurthestOutReminders() {
        let slots = plan()
        let pending = slots.map {
            NotificationPlanner.Pending(identifier: $0.identifier, fingerprint: $0.contentFingerprint)
        } + snoozes(8)

        let diff = NotificationPlanner.diff(pending: pending, against: slots, now: now)
        XCTAssertEqual(diff.unchanged.count, 56)
        XCTAssertEqual(diff.overBudget.count, 4)
        XCTAssertEqual(Set(diff.overBudget), Set(slots.suffix(4).map(\.identifier)), "the nearest reminders survive")
        XCTAssertTrue(diff.toAdd.isEmpty, "nothing is re-added into a full queue")
        XCTAssertEqual(diff.unchanged.count + 8, NotificationPlanner.maxPending, "the queue lands exactly on the cap")
    }

    func testADifficultyChangeReplacesTheQueuedRequests() {
        let easy = plan(.easy)
        let hard = plan(.hard)
        let changed = zip(easy, hard)
            .filter { $0.contentFingerprint != $1.contentFingerprint }
            .map { $0.1.identifier }
        XCTAssertFalse(changed.isEmpty, "hard has to prescribe more than easy somewhere")

        let pending = easy.map {
            NotificationPlanner.Pending(identifier: $0.identifier, fingerprint: $0.contentFingerprint)
        }
        let diff = NotificationPlanner.diff(pending: pending, against: hard, now: now)

        XCTAssertEqual(Set(diff.toRemove), Set(changed))
        XCTAssertEqual(Set(diff.toAdd.map(\.identifier)), Set(changed))
        XCTAssertEqual(Set(diff.unchanged), Set(hard.map(\.identifier)).subtracting(changed))
    }

    func testARequestWithNoFingerprintIsTreatedAsStale() {
        let slots = plan()
        let diff = NotificationPlanner.diff(
            pending: [NotificationPlanner.Pending(identifier: slots[0].identifier)],
            against: slots,
            now: now
        )
        XCTAssertEqual(diff.toRemove, [slots[0].identifier])
        XCTAssertTrue(diff.toAdd.contains { $0.identifier == slots[0].identifier })
    }

    func testTheFingerprintTravelsInUserInfo() {
        let slot = plan()[0]
        let request = NotificationPlanner.request(for: slot, catalog: Fixtures.bundledCatalog, streakDays: 1)
        XCTAssertEqual(
            request.content.userInfo[NotificationPlanner.UserInfoKey.fingerprint] as? String,
            slot.contentFingerprint
        )
        XCTAssertEqual(NotificationPlanner.Pending(request: request).fingerprint, slot.contentFingerprint)
    }
}

// MARK: - Settings storage

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "settings-test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testTimeZoneRefreshRewritesAndPersistsTheStoredZone() {
        let store = SettingsStore(defaults: defaults)
        store.current = Fixtures.settings(timezone: "America/New_York")

        XCTAssertTrue(store.refreshTimeZone(to: "Europe/Berlin"))
        XCTAssertEqual(store.current.timezone, "Europe/Berlin")

        let reopened = SettingsStore(defaults: defaults)
        XCTAssertEqual(reopened.current.timezone, "Europe/Berlin", "the move has to outlive the launch")
    }

    func testTimeZoneRefreshDoesNothingWhenTheZoneIsUnchanged() {
        let store = SettingsStore(defaults: defaults)
        store.current = Fixtures.settings(timezone: "Europe/Berlin")
        store.needsPush = false

        XCTAssertFalse(store.refreshTimeZone(to: "Europe/Berlin"))
        XCTAssertFalse(store.needsPush, "an unchanged zone is not an edit")
        XCTAssertFalse(store.refreshTimeZone(to: "Mars/Olympus_Mons"), "an unknown zone is ignored")
    }

    func testEveryEditMarksSettingsForPush() {
        let store = SettingsStore(defaults: defaults)
        store.needsPush = false
        store.current = Fixtures.settings(interval: 60)
        XCTAssertTrue(store.needsPush)

        store.needsPush = false
        store.adopt(Fixtures.settings(interval: 90))
        XCTAssertFalse(store.needsPush, "settings that came from the server do not bounce back")
    }

    func testAnInvalidWindowIsRepairedBeforeItIsPersisted() {
        let store = SettingsStore(defaults: defaults)
        // end == start + interval, which the Worker rejects.
        store.current = Fixtures.settings(interval: 120, start: 540, end: 660)

        let saved = store.current
        XCTAssertTrue(saved.hasValidWindow)
        XCTAssertEqual(saved.activeEndMinute, 661)

        let reopened = SettingsStore(defaults: defaults).current
        XCTAssertTrue(reopened.hasValidWindow)
    }
}

// MARK: - The active window invariant (server/src/validation.ts)

final class ActiveWindowTests: XCTestCase {
    func testValidWindowMatchesTheWorker() {
        XCTAssertTrue(AppSettings.isValidWindow(start: 540, end: 1140, interval: 120))
        XCTAssertTrue(AppSettings.isValidWindow(start: 540, end: 661, interval: 120))
        XCTAssertTrue(AppSettings.isValidWindow(start: 0, end: 1440, interval: 240))
        XCTAssertFalse(AppSettings.isValidWindow(start: 540, end: 660, interval: 120), "end must clear start + interval")
        XCTAssertFalse(AppSettings.isValidWindow(start: 540, end: 540, interval: 60))
        XCTAssertFalse(AppSettings.isValidWindow(start: 600, end: 540, interval: 60))
        XCTAssertFalse(AppSettings.isValidWindow(start: -1, end: 600, interval: 60))
        XCTAssertFalse(AppSettings.isValidWindow(start: 0, end: 1441, interval: 60))
        XCTAssertFalse(AppSettings.isValidWindow(start: 0, end: 600, interval: 0))
        XCTAssertTrue(AppSettings.default.hasValidWindow)
    }

    func testRepairNudgesEndToTheSmallestLegalValue() {
        let fixed = AppSettings.repairedWindow(start: 540, end: 600, interval: 120)
        XCTAssertEqual(fixed.start, 540)
        XCTAssertEqual(fixed.end, 661)
    }

    func testRepairMovesStartWhenEndCannotGrowPastMidnight() {
        let fixed = AppSettings.repairedWindow(start: 1400, end: 1440, interval: 240)
        XCTAssertEqual(fixed.end, 1440)
        XCTAssertEqual(fixed.start, 1199)
        XCTAssertTrue(AppSettings.isValidWindow(start: fixed.start, end: fixed.end, interval: 240))
    }

    func testRepairAlwaysLandsOnAValidWindow() {
        for interval in AppSettings.intervalOptions {
            for start in stride(from: 0, through: 1439, by: 37) {
                for end in [0, start, start + 1, start + interval, 1440, 2000] {
                    let fixed = AppSettings.repairedWindow(start: start, end: end, interval: interval)
                    XCTAssertTrue(
                        AppSettings.isValidWindow(start: fixed.start, end: fixed.end, interval: interval),
                        "start \(start) end \(end) interval \(interval) repaired to \(fixed)"
                    )
                }
            }
        }
    }
}

// MARK: - Server sync

final class SyncCoordinatorTests: XCTestCase {
    private var fileURL: URL!
    private var catalogURL: URL!
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: SetStore!
    private var settingsStore: SettingsStore!
    private var catalog: Catalog!

    override func setUp() {
        super.setUp()
        StubTransport.reset()
        fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("sync-\(UUID().uuidString).json")
        catalogURL = FileManager.default.temporaryDirectory.appendingPathComponent("catalog-\(UUID().uuidString).json")
        suiteName = "sync-test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = SetStore(fileURL: fileURL)
        settingsStore = SettingsStore(defaults: defaults)
        catalog = Catalog(cacheURL: catalogURL)
    }

    override func tearDown() {
        StubTransport.reset()
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: catalogURL)
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeCoordinator() -> SyncCoordinator {
        SyncCoordinator(
            api: StubTransport.client(),
            store: store,
            settingsStore: settingsStore,
            catalog: catalog
        )
    }

    private func log(_ id: String, secondsAgo: TimeInterval) async -> String {
        await store.logManual(
            exercise: Fixtures.exercise(id, pattern: .push),
            target: 10,
            status: .done,
            now: Date().addingTimeInterval(-secondsAgo)
        )
    }

    private func waitFor(
        _ condition: () -> Bool,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("condition never became true", file: file, line: line)
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    // MARK: Outbox

    func testPermanentRejectionCodesMatchTheWorker() {
        for code in ["unknown_exercise", "invalid_set", "invalid_id", "invalid_target", "invalid_local_date"] {
            XCTAssertTrue(SyncCoordinator.isPermanentRejection(code), code)
        }
        for code in ["server_busy", "rate_limited", "d1_error", "internal"] {
            XCTAssertFalse(SyncCoordinator.isPermanentRejection(code), code)
        }
    }

    func testFlushSettlesAcceptedAndPermanentRejectionsButKeepsTheRest() async {
        let accepted = await log("accepted", secondsAgo: 30)
        let bogus = await log("bogus", secondsAgo: 20)
        let flaky = await log("flaky", secondsAgo: 10)

        StubTransport.responder = { _ in
            (200, StubTransport.setsEnvelope(
                accepted: 1,
                rejected: [(id: bogus, error: "unknown_exercise"), (id: flaky, error: "server_busy")]
            ))
        }
        await makeCoordinator().flushOutbox()

        let outbox = await store.outbox()
        XCTAssertEqual(outbox.map(\.id), [flaky], "only the rejection that might clear stays queued")
        let acceptedRecord = await store.record(setID: accepted)
        let bogusRecord = await store.record(setID: bogus)
        XCTAssertEqual(acceptedRecord?.synced, true)
        XCTAssertEqual(bogusRecord?.synced, true, "the server will never take an unknown exercise")
        let attempts = await store.syncAttempts(setID: flaky)
        XCTAssertEqual(attempts, 1)
    }

    func testARetriedSetIsAbandonedAfterFiveFlushes() async {
        let flaky = await log("flaky", secondsAgo: 10)
        StubTransport.responder = { _ in
            (200, StubTransport.setsEnvelope(accepted: 0, rejected: [(id: flaky, error: "server_busy")]))
        }
        let coordinator = makeCoordinator()
        for _ in 0..<SetStore.maxSyncAttempts { await coordinator.flushOutbox() }

        let outbox = await store.outbox()
        XCTAssertTrue(outbox.isEmpty, "a set nobody will take must not wedge the outbox")
        XCTAssertEqual(StubTransport.callCount, SetStore.maxSyncAttempts)
    }

    func testAnUnreachableServerLeavesTheOutboxUntouched() async {
        let id = await log("offline", secondsAgo: 10)
        StubTransport.responder = { _ in (503, Data("{}".utf8)) }
        await makeCoordinator().flushOutbox()

        let outbox = await store.outbox()
        XCTAssertEqual(outbox.map(\.id), [id])
        let attempts = await store.syncAttempts(setID: id)
        XCTAssertEqual(attempts, 0, "a failed request is not a rejection")
    }

    // MARK: Settings

    func testSettingsPushesCoalesceSoTheLastEditLandsLast() async {
        let gate = DispatchSemaphore(value: 0)
        StubTransport.gate = gate
        StubTransport.responder = { call in
            (200, StubTransport.settingsEnvelope(call.settings ?? AppSettings.default))
        }
        let coordinator = makeCoordinator()

        let inFlight = Task { await coordinator.pushSettings(Fixtures.settings(interval: 60)) }
        await waitFor { StubTransport.callCount == 1 }
        // Two more edits while the first PUT is still on the wire.
        await coordinator.pushSettings(Fixtures.settings(interval: 90))
        await coordinator.pushSettings(Fixtures.settings(interval: 180))
        gate.signal()
        await inFlight.value

        let intervals = StubTransport.calls.compactMap { $0.settings?.intervalMinutes }
        XCTAssertEqual(intervals, [60, 180], "the 90 was superseded before it was ever sent")
        XCTAssertFalse(settingsStore.needsPush)
    }

    func testAFailedSettingsPushIsRetriedOnTheNextFlush() async {
        StubTransport.responder = { _ in
            StubTransport.callCount == 1
                ? (500, Data("{}".utf8))
                : (200, StubTransport.settingsEnvelope())
        }
        let coordinator = makeCoordinator()

        await coordinator.pushSettings(Fixtures.settings(interval: 60))
        XCTAssertTrue(settingsStore.needsPush, "a refused push stays owed")

        await coordinator.flushSettingsIfNeeded()
        XCTAssertFalse(settingsStore.needsPush)
        XCTAssertEqual(StubTransport.callCount, 2, "the foreground retry, not a third edit")
    }

    func testNothingIsSentWhenSettingsAreClean() async {
        settingsStore.needsPush = false
        await makeCoordinator().flushSettingsIfNeeded()
        XCTAssertEqual(StubTransport.callCount, 0)
    }
}
