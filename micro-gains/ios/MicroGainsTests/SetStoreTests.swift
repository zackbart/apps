import XCTest
@testable import MicroGains

final class SetStoreTests: XCTestCase {
    private var fileURL: URL!
    private var store: SetStore!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sets-\(UUID().uuidString).json")
        store = SetStore(fileURL: fileURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func slots(count: Int = 3) -> [Slot] {
        Scheduler.plan(
            settings: Fixtures.settings(),
            catalog: Fixtures.smallCatalog,
            now: Fixtures.date(2026, 6, 1, 0, 1),
            deviceID: Fixtures.deviceID
        ).prefix(count).map { $0 }
    }

    func testRegisterIsIdempotent() async {
        let slots = slots()
        await store.register(slots: slots)
        await store.register(slots: slots)
        let records = await store.allRecords()
        XCTAssertEqual(records.count, slots.count)
        XCTAssertTrue(records.allSatisfy { $0.state == .scheduled })
    }

    func testRegisterDoesNotResurrectAFinishedSlot() async {
        let slots = slots()
        await store.register(slots: slots)
        let id = slots[0].setID.uuidString
        _ = await store.log(setID: id, status: .done, source: .notification)

        await store.register(slots: slots)
        let record = await store.record(setID: id)
        XCTAssertEqual(record?.state, .done)
    }

    func testFirstTerminalWriteWins() async {
        let slots = slots()
        await store.register(slots: slots)
        let id = slots[0].setID.uuidString

        let first = await store.log(setID: id, status: .done, source: .notification)
        let second = await store.log(setID: id, status: .skipped, reason: .badTime, source: .app)

        XCTAssertTrue(first, "the banner Done should land")
        XCTAssertFalse(second, "the Set screen Skip must not overwrite it")

        let record = await store.record(setID: id)
        XCTAssertEqual(record?.state, .done)
        XCTAssertNil(record?.skipReason)
        XCTAssertEqual(record?.source, .notification)
    }

    func testExpiredIsAlsoTerminal() async {
        let slots = slots()
        await store.register(slots: slots)
        let id = slots[0].setID.uuidString

        await store.expireStale(
            now: slots[0].scheduledAt.addingTimeInterval(3 * 3600),
            intervalMinutes: 120
        )
        let expired = await store.record(setID: id)
        XCTAssertEqual(expired?.state, .expired)

        let late = await store.log(setID: id, status: .done, source: .app)
        XCTAssertFalse(late)
    }

    func testExpireLeavesFutureSlotsAlone() async {
        let slots = slots()
        await store.register(slots: slots)
        await store.expireStale(now: Fixtures.date(2026, 6, 1, 0, 5), intervalMinutes: 120)
        let records = await store.allRecords()
        XCTAssertTrue(records.allSatisfy { $0.state == .scheduled })
    }

    func testSnoozeKeepsTheSlotOpenAndFlagsIt() async {
        let slots = slots()
        await store.register(slots: slots)
        let id = slots[0].setID.uuidString
        let newFire = slots[0].scheduledAt.addingTimeInterval(600)

        await store.markSnoozed(setID: id, newFireDate: newFire)
        let record = await store.record(setID: id)
        XCTAssertEqual(record?.snoozed, true)
        XCTAssertEqual(record?.state, .delivered)
        let logged = await store.log(setID: id, status: .done, source: .notification)
        XCTAssertTrue(logged)
    }

    func testSnoozeLeavesScheduledAtWhereItWas() async {
        let slots = slots()
        await store.register(slots: slots)
        let id = slots[0].setID.uuidString
        let newFire = slots[0].scheduledAt.addingTimeInterval(600)

        await store.markSnoozed(setID: id, newFireDate: newFire)
        let record = await store.record(setID: id)
        XCTAssertEqual(record?.scheduledAt, slots[0].scheduledAt, "the logged slot time must not move")
        XCTAssertEqual(record?.snoozedUntil, newFire)
        XCTAssertEqual(record?.dueAt, newFire, "but the slot is now due ten minutes later")

        _ = await store.log(setID: id, status: .done, source: .notification)
        let log = await store.outbox().first
        XCTAssertEqual(log?.scheduledAt, slots[0].scheduledAt)
    }

    func testOutboxHoldsOnlyFinishedUnsyncedSets() async {
        let slots = slots()
        await store.register(slots: slots)
        let empty = await store.outbox()
        XCTAssertTrue(empty.isEmpty, "a scheduled slot owes the server nothing")

        _ = await store.log(setID: slots[0].setID.uuidString, status: .done, source: .notification)
        _ = await store.log(setID: slots[1].setID.uuidString, status: .skipped, reason: .tooHard, source: .app)

        let outbox = await store.outbox()
        XCTAssertEqual(outbox.count, 2)
        XCTAssertEqual(outbox.first?.status, .done)
        XCTAssertEqual(outbox.last?.skipReason, .tooHard)
    }

    func testFlushMarksSyncedAndEmptiesTheOutbox() async {
        let slots = slots()
        await store.register(slots: slots)
        _ = await store.log(setID: slots[0].setID.uuidString, status: .done, source: .notification)

        let outbox = await store.outbox()
        await store.markSynced(ids: outbox.map(\.id))

        let drained = await store.outbox()
        XCTAssertTrue(drained.isEmpty)
        let record = await store.record(setID: slots[0].setID.uuidString)
        XCTAssertEqual(record?.synced, true)
    }

    func testManualSetLandsInTheOutboxWithAppSource() async {
        let exercise = Fixtures.exercise("air_squat", pattern: .squat)
        let id = await store.logManual(exercise: exercise, target: 18, status: .done)
        let outbox = await store.outbox()
        XCTAssertEqual(outbox.count, 1)
        XCTAssertEqual(outbox[0].id, id)
        XCTAssertEqual(outbox[0].source, .app)
        XCTAssertNil(outbox[0].scheduledAt)
    }

    func testPersistsAcrossInstances() async {
        let slots = slots()
        await store.register(slots: slots)
        _ = await store.log(setID: slots[0].setID.uuidString, status: .done, source: .app)

        let reopened = SetStore(fileURL: fileURL)
        let record = await reopened.record(setID: slots[0].setID.uuidString)
        XCTAssertEqual(record?.state, .done)
        let reopenedRecords = await reopened.allRecords()
        XCTAssertEqual(reopenedRecords.count, slots.count)
    }

    func testWipeClearsEverything() async {
        await store.register(slots: slots())
        await store.wipe()
        let remaining = await store.allRecords()
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testTodaySummaryCountsDotsInTimeOrder() async {
        let settings = Fixtures.settings()
        let now = Fixtures.date(2026, 6, 1, 0, 1)
        let all = Scheduler.plan(
            settings: settings,
            catalog: Fixtures.smallCatalog,
            now: now,
            deviceID: Fixtures.deviceID
        )
        await store.register(slots: all)
        _ = await store.log(
            setID: all[0].setID.uuidString,
            status: .done,
            source: .notification,
            now: now,
            timeZone: settings.timeZone
        )

        let summary = await store.today(now: now, timeZone: settings.timeZone)
        XCTAssertEqual(summary.dots.count, 5)
        XCTAssertEqual(summary.done, 1)
        XCTAssertEqual(summary.remaining, 4)
        XCTAssertEqual(summary.dots.first, .done)
    }

    func testHistoryFillsEveryDayInRange() async {
        let settings = Fixtures.settings()
        let now = Fixtures.date(2026, 6, 10, 12, 0)
        let days = await store.history(days: 30, now: now, timeZone: settings.timeZone)
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(days.last?.date, "2026-06-10")
        XCTAssertTrue(days.allSatisfy { $0.done == 0 && $0.skipped == 0 })
    }

    func testStatsSumRepsAndSecondsSeparately() async {
        let now = Fixtures.date(2026, 6, 10, 12, 0)
        let settings = Fixtures.settings()
        _ = await store.logManual(
            exercise: Fixtures.exercise("squat", pattern: .squat, unit: .reps),
            target: 18, status: .done, now: now, timeZone: settings.timeZone
        )
        _ = await store.logManual(
            exercise: Fixtures.exercise("plank", pattern: .core, unit: .seconds),
            target: 40, status: .done, now: now, timeZone: settings.timeZone
        )
        _ = await store.logManual(
            exercise: Fixtures.exercise("squat", pattern: .squat, unit: .reps),
            target: 18, status: .skipped, reason: .badTime, now: now, timeZone: settings.timeZone
        )

        let stats = await store.stats(now: now, settings: settings)
        XCTAssertEqual(stats.totalDone, 2)
        XCTAssertEqual(stats.totalReps, 18)
        XCTAssertEqual(stats.totalSeconds, 40)
        XCTAssertEqual(stats.todayDone, 2)
        XCTAssertEqual(stats.todaySkipped, 1)
        XCTAssertEqual(stats.streakDays, 1)
    }

    func testStreakCountsConsecutiveActiveDays() async {
        let settings = Fixtures.settings()
        let calendar = Fixtures.calendar()
        let now = Fixtures.date(2026, 6, 10, 12, 0)
        for offset in 0..<3 {
            let day = calendar.date(byAdding: .day, value: -offset, to: now)!
            _ = await store.logManual(
                exercise: Fixtures.exercise("squat", pattern: .squat),
                target: 18, status: .done, now: day, timeZone: settings.timeZone
            )
        }
        let stats = await store.stats(now: now, settings: settings)
        XCTAssertEqual(stats.streakDays, 3)
        XCTAssertGreaterThanOrEqual(stats.bestStreakDays, 3)
    }

    func testRestDaysNeitherBreakNorExtendTheStreak() async {
        // Weekdays only. Logging Thursday and Friday should read as 2 on the
        // following Monday, with the weekend transparent.
        let settings = Fixtures.settings(days: 0b0011111)
        let monday = Fixtures.date(2026, 6, 8, 12, 0)   // Monday
        let calendar = Fixtures.calendar()
        for offset in [3, 4] { // the Thursday and Friday before
            let day = calendar.date(byAdding: .day, value: -offset, to: monday)!
            _ = await store.logManual(
                exercise: Fixtures.exercise("squat", pattern: .squat),
                target: 18, status: .done, now: day, timeZone: settings.timeZone
            )
        }
        let stats = await store.stats(now: monday, settings: settings)
        XCTAssertEqual(stats.streakDays, 2, "an empty Monday must not end Thursday and Friday")
    }

    // MARK: - Replanning an already-queued slot

    private func plan(difficulty: Difficulty, days: Int = 127) -> [Slot] {
        Scheduler.plan(
            settings: Fixtures.settings(difficulty: difficulty, days: days),
            catalog: Fixtures.smallCatalog,
            now: Fixtures.date(2026, 6, 1, 0, 1),
            deviceID: Fixtures.deviceID
        )
    }

    func testRegisterUpdatesAScheduledSlotWhenTheTargetChanged() async {
        let easy = Array(plan(difficulty: .easy).prefix(3))
        await store.register(slots: easy)

        let hard = Array(plan(difficulty: .hard).prefix(3))
        XCTAssertEqual(hard[0].identifier, easy[0].identifier, "same slot, new prescription")
        XCTAssertNotEqual(hard[0].target, easy[0].target)
        await store.register(slots: hard)

        let record = await store.record(setID: easy[0].setID.uuidString)
        XCTAssertEqual(record?.setID, easy[0].setID.uuidString, "the set id is the slot's identity")
        XCTAssertEqual(record?.target, hard[0].target)
        XCTAssertEqual(record?.exerciseID, hard[0].exerciseID)
        XCTAssertEqual(record?.slot?.contentFingerprint, hard[0].contentFingerprint)
        XCTAssertEqual(record?.state, .scheduled)
        let all = await store.allRecords()
        XCTAssertEqual(all.count, 3, "updating in place must not fork the record")
    }

    func testRegisterLeavesADeliveredSlotAlone() async {
        let easy = Array(plan(difficulty: .easy).prefix(3))
        await store.register(slots: easy)
        await store.markDelivered(setID: easy[0].setID.uuidString)

        await store.register(slots: Array(plan(difficulty: .hard).prefix(3)))
        let record = await store.record(setID: easy[0].setID.uuidString)
        XCTAssertEqual(record?.state, .delivered)
        XCTAssertEqual(record?.target, easy[0].target, "the user already saw this one")
    }

    // MARK: - Expiry (rule 6)

    func testFridaysLastSetSurvivesAWeekendOff() async {
        // Weekdays only. Friday 17:00 with a two hour interval: the old rule
        // expired it at 19:00 Friday, but the next real slot is Monday 09:00.
        let settings = Fixtures.settings(days: 0b0011111)
        let slots = Scheduler.plan(
            settings: settings,
            catalog: Fixtures.smallCatalog,
            now: Fixtures.date(2026, 6, 5, 0, 1),   // Friday
            deviceID: Fixtures.deviceID
        )
        await store.register(slots: slots)
        let friday = slots.filter { $0.localDate == "2026-06-05" }
        XCTAssertEqual(friday.count, 5)
        let last = friday[friday.count - 1]
        let earlier = friday[0]

        await store.expireStale(
            now: Fixtures.date(2026, 6, 6, 12, 0),  // Saturday lunchtime
            intervalMinutes: settings.intervalMinutes
        )
        var record = await store.record(setID: last.setID.uuidString)
        XCTAssertEqual(record?.state, .scheduled, "nothing has come due since Friday evening")
        let stale = await store.record(setID: earlier.setID.uuidString)
        XCTAssertEqual(stale?.state, .expired, "the 09:00 slot lost its turn at 11:00")

        await store.expireStale(
            now: Fixtures.date(2026, 6, 8, 11, 30), // Monday, after the 09:00 slot
            intervalMinutes: settings.intervalMinutes
        )
        record = await store.record(setID: last.setID.uuidString)
        XCTAssertEqual(record?.state, .expired)
    }

    func testExpiryFallsBackToTheIntervalWhenNoLaterSlotExists() async {
        let slots = slots(count: 1)
        await store.register(slots: slots)
        await store.expireStale(
            now: slots[0].scheduledAt.addingTimeInterval(90 * 60),
            intervalMinutes: 120
        )
        var record = await store.record(setID: slots[0].setID.uuidString)
        XCTAssertEqual(record?.state, .scheduled, "still inside the interval")

        await store.expireStale(
            now: slots[0].scheduledAt.addingTimeInterval(150 * 60),
            intervalMinutes: 120
        )
        record = await store.record(setID: slots[0].setID.uuidString)
        XCTAssertEqual(record?.state, .expired)
    }

    func testSnoozedSlotDoesNotExpireBeforeItFires() async {
        let slots = slots(count: 1)
        await store.register(slots: slots)
        let id = slots[0].setID.uuidString
        await store.markSnoozed(setID: id, newFireDate: slots[0].scheduledAt.addingTimeInterval(600))

        // Past the interval measured from the original time, short of it
        // measured from the snooze.
        await store.expireStale(
            now: slots[0].scheduledAt.addingTimeInterval(125 * 60),
            intervalMinutes: 120
        )
        let record = await store.record(setID: id)
        XCTAssertEqual(record?.state, .delivered, "the snooze bought it another ten minutes")
    }

    // MARK: - Outbox retries

    func testRetriedSetIsDroppedAfterFiveTries() async {
        let id = await store.logManual(exercise: Fixtures.exercise("squat", pattern: .squat), target: 18, status: .done)

        for attempt in 1...4 {
            let abandoned = await store.markSyncRetry(ids: [id])
            XCTAssertTrue(abandoned.isEmpty)
            let count = await store.syncAttempts(setID: id)
            XCTAssertEqual(count, attempt)
            let outbox = await store.outbox()
            XCTAssertEqual(outbox.count, 1, "still owed to the server")
        }

        let abandoned = await store.markSyncRetry(ids: [id])
        XCTAssertEqual(abandoned, [id])
        let outbox = await store.outbox()
        XCTAssertTrue(outbox.isEmpty, "one poisoned set must not wedge the queue")
    }
}
