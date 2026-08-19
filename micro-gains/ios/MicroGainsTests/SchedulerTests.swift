import XCTest
@testable import MicroGains

final class SchedulerTests: XCTestCase {
    /// XCTUnwrap is throwing; these fixtures are known good.
    private func XCTUnwrap0<T>(_ value: T?) -> T {
        guard let value else { preconditionFailure("fixture missing") }
        return value
    }

    private let zone = "America/New_York"

    private func plan(
        settings: AppSettings,
        catalog: [Exercise] = Fixtures.bundledCatalog,
        now: Date,
        recent: [Slot] = []
    ) -> [Slot] {
        Scheduler.plan(
            settings: settings,
            catalog: catalog,
            now: now,
            deviceID: Fixtures.deviceID,
            recent: recent
        )
    }

    // MARK: - Rule 1: generation, count and spacing

    func testFillsTheBudgetAndStopsAtSixty() {
        let slots = plan(settings: Fixtures.settings(), now: Fixtures.date(2026, 6, 1, 8, 0))
        XCTAssertEqual(slots.count, Scheduler.maxSlots)
    }

    func testSlotsAreOneIntervalApartWithinADay() {
        let settings = Fixtures.settings()
        let slots = plan(settings: settings, now: Fixtures.date(2026, 6, 1, 0, 1))
        let firstDay = slots.filter { $0.localDate == "2026-06-01" }
        XCTAssertEqual(firstDay.count, 5, "09:00 to 19:00 every 2 h, end exclusive")

        for (a, b) in zip(firstDay, firstDay.dropFirst()) {
            let gap = b.unjitteredAt.timeIntervalSince(a.unjitteredAt)
            XCTAssertEqual(gap, Double(settings.intervalMinutes * 60), accuracy: 1)
        }
    }

    func testSlotsStayInsideTheActiveWindow() {
        let settings = Fixtures.settings(interval: 60, start: 480, end: 1080)
        let slots = plan(settings: settings, now: Fixtures.date(2026, 6, 1, 0, 1))
        let calendar = Fixtures.calendar(zone)

        for slot in slots {
            let minute = calendar.component(.hour, from: slot.unjitteredAt) * 60
                + calendar.component(.minute, from: slot.unjitteredAt)
            XCTAssertGreaterThanOrEqual(minute, settings.activeStartMinute)
            XCTAssertLessThan(minute, settings.activeEndMinute)

            let jitteredMinute = calendar.component(.hour, from: slot.scheduledAt) * 60
                + calendar.component(.minute, from: slot.scheduledAt)
            XCTAssertGreaterThanOrEqual(jitteredMinute, settings.activeStartMinute)
            XCTAssertLessThan(jitteredMinute, settings.activeEndMinute)
        }
    }

    func testFirstSlotIsStrictlyAfterNow() {
        let now = Fixtures.date(2026, 6, 1, 13, 0)
        let slots = plan(settings: Fixtures.settings(), now: now)
        XCTAssertGreaterThan(slots[0].unjitteredAt, now)
        XCTAssertEqual(slots[0].localDate, "2026-06-01")
    }

    func testActiveDaysMaskSkipsWeekends() {
        // Bits 0..4 are Monday to Friday.
        let settings = Fixtures.settings(days: 0b0011111)
        let slots = plan(settings: settings, now: Fixtures.date(2026, 6, 1, 0, 1))
        let calendar = Fixtures.calendar(zone)
        for slot in slots {
            let weekday = calendar.component(.weekday, from: slot.unjitteredAt)
            XCTAssertFalse(weekday == 1 || weekday == 7, "weekend slot leaked through: \(slot.localDate)")
        }
        XCTAssertFalse(slots.isEmpty)
    }

    func testSingleActiveDayOnlyProducesThatWeekday() {
        // Bit 2 is Wednesday.
        let slots = plan(settings: Fixtures.settings(days: 0b0000100), now: Fixtures.date(2026, 6, 1, 0, 1))
        let calendar = Fixtures.calendar(zone)
        XCTAssertFalse(slots.isEmpty)
        for slot in slots {
            XCTAssertEqual(calendar.component(.weekday, from: slot.unjitteredAt), 4)
        }
    }

    func testPausedUntilSkipsEarlierSlotsButKeepsThePipeline() {
        let pausedUntil = Fixtures.date(2026, 6, 3, 9, 0)
        let slots = plan(
            settings: Fixtures.settings(pausedUntil: pausedUntil),
            now: Fixtures.date(2026, 6, 1, 0, 1)
        )
        XCTAssertFalse(slots.isEmpty)
        XCTAssertTrue(slots.allSatisfy { $0.unjitteredAt >= pausedUntil })
    }

    func testDisabledProducesNothing() {
        XCTAssertTrue(plan(settings: Fixtures.settings(enabled: false), now: Fixtures.date(2026, 6, 1)).isEmpty)
    }

    // MARK: - Rule 2 and 3: jitter and identity

    func testJitterIsWithinFiveMinutesAndDeterministic() {
        let settings = Fixtures.settings()
        let now = Fixtures.date(2026, 6, 1, 0, 1)
        let first = plan(settings: settings, now: now)
        let second = plan(settings: settings, now: now)

        XCTAssertEqual(first, second, "re-running the scheduler must reproduce every slot exactly")
        for slot in first {
            let drift = abs(slot.scheduledAt.timeIntervalSince(slot.unjitteredAt))
            XCTAssertLessThanOrEqual(drift, Double(Scheduler.jitterMinutes * 60))
        }
    }

    func testJitterActuallyMovesSomeSlots() {
        let slots = plan(settings: Fixtures.settings(), now: Fixtures.date(2026, 6, 1, 0, 1))
        let moved = slots.filter { $0.scheduledAt != $0.unjitteredAt }
        XCTAssertGreaterThan(moved.count, slots.count / 3, "a fixed offset would not be jitter")
    }

    func testDifferentDevicesGetDifferentJitter() {
        let settings = Fixtures.settings()
        let now = Fixtures.date(2026, 6, 1, 0, 1)
        let mine = plan(settings: settings, now: now)
        let theirs = Scheduler.plan(
            settings: settings,
            catalog: Fixtures.bundledCatalog,
            now: now,
            deviceID: "99999999-8888-4777-8666-555555555555"
        )
        XCTAssertNotEqual(mine.map(\.scheduledAt), theirs.map(\.scheduledAt))
        XCTAssertEqual(mine.map(\.identifier), theirs.map(\.identifier), "identifiers key off the unjittered time only")
    }

    func testIdentifierAndSetIDShape() {
        let slots = plan(settings: Fixtures.settings(), now: Fixtures.date(2026, 6, 1, 0, 1))
        let slot = slots[0]
        XCTAssertEqual(slot.identifier, "slot-" + ISO8601.utc.string(from: slot.unjitteredAt))
        XCTAssertTrue(slot.identifier.hasSuffix("Z"))
        XCTAssertEqual(slot.setID, UUIDv5.make(namespace: UUIDv5.slotNamespace, name: slot.identifier))
        XCTAssertEqual(Set(slots.map(\.identifier)).count, slots.count, "identifiers must be unique")
    }

    // MARK: - Rule 4: selection constraints

    func testNoTwoConsecutiveSlotsShareAPattern() {
        let slots = plan(settings: Fixtures.settings(), now: Fixtures.date(2026, 6, 1, 0, 1))
        for (a, b) in zip(slots, slots.dropFirst()) {
            XCTAssertNotEqual(a.pattern, b.pattern, "\(a.exerciseID) then \(b.exerciseID)")
        }
    }

    func testAtMostTwoOfAnyPatternPerLocalDay() {
        let slots = plan(settings: Fixtures.settings(interval: 60), now: Fixtures.date(2026, 6, 1, 0, 1))
        var counts: [String: [Pattern: Int]] = [:]
        for slot in slots {
            counts[slot.localDate, default: [:]][slot.pattern, default: 0] += 1
        }
        for (day, byPattern) in counts {
            for (pattern, count) in byPattern {
                XCTAssertLessThanOrEqual(count, 2, "\(pattern) appeared \(count) times on \(day)")
            }
        }
    }

    func testSamePatternRespectsTheThreeHourCooldown() {
        let slots = plan(settings: Fixtures.settings(interval: 60), now: Fixtures.date(2026, 6, 1, 0, 1))
        for (index, slot) in slots.enumerated() {
            for other in slots[(index + 1)...] where other.pattern == slot.pattern {
                let gap = other.unjitteredAt.timeIntervalSince(slot.unjitteredAt)
                if gap >= Scheduler.patternCooldown { break }
                XCTFail("\(slot.pattern) repeated after only \(Int(gap / 60)) min")
            }
        }
    }

    func testFirstSlotOfADayIsNeverIntense() {
        let slots = plan(settings: Fixtures.settings(interval: 60), now: Fixtures.date(2026, 6, 1, 0, 1))
        let firsts = slots.filter(\.isFirstOfDay)
        XCTAssertGreaterThan(firsts.count, 3)
        for slot in firsts {
            XCTAssertFalse(slot.intense, "\(slot.exerciseID) opened \(slot.localDate) cold")
        }
    }

    func testOfficeModeOnlyPicksDeskFriendlyExercises() {
        let slots = plan(settings: Fixtures.settings(office: true), now: Fixtures.date(2026, 6, 1, 0, 1))
        XCTAssertFalse(slots.isEmpty)
        for slot in slots {
            let exercise = Fixtures.bundledCatalog.first { $0.id == slot.exerciseID }
            XCTAssertEqual(exercise?.officeOk, true, "\(slot.exerciseID) is not office friendly")
        }
    }

    func testFloorOffExcludesFloorExercises() {
        let slots = plan(settings: Fixtures.settings(floor: false), now: Fixtures.date(2026, 6, 1, 0, 1))
        XCTAssertFalse(slots.isEmpty)
        for slot in slots {
            let exercise = Fixtures.bundledCatalog.first { $0.id == slot.exerciseID }
            XCTAssertEqual(exercise?.needsFloor, false, "\(slot.exerciseID) needs the floor")
        }
    }

    func testFiltersFallBackWhenTheyWouldEmptyTheCatalog() {
        // Nothing in this catalog is office friendly, so office mode has to be
        // ignored rather than leaving the user with no reminders at all.
        let catalog = [
            Fixtures.exercise("floor_push", pattern: .push, officeOk: false, needsFloor: true),
            Fixtures.exercise("floor_core", pattern: .core, officeOk: false, needsFloor: true)
        ]
        let slots = plan(
            settings: Fixtures.settings(office: true, floor: false),
            catalog: catalog,
            now: Fixtures.date(2026, 6, 1, 0, 1)
        )
        XCTAssertFalse(slots.isEmpty, "an impossible filter must not silence the app")
        XCTAssertTrue(slots.allSatisfy { ["floor_push", "floor_core"].contains($0.exerciseID) })
    }

    func testSinglePatternCatalogStillSchedules() {
        // Every pattern rule points at the same one item; all of them relax.
        let catalog = [Fixtures.exercise("only", pattern: .core)]
        let slots = plan(settings: Fixtures.settings(), catalog: catalog, now: Fixtures.date(2026, 6, 1, 0, 1))
        XCTAssertEqual(slots.count, Scheduler.maxSlots)
        XCTAssertTrue(slots.allSatisfy { $0.exerciseID == "only" })
    }

    func testTargetUsesDifficulty() {
        let catalog = [Fixtures.exercise("only", pattern: .core, easy: 3, medium: 9, hard: 27)]
        for (difficulty, expected) in [(Difficulty.easy, 3), (.medium, 9), (.hard, 27)] {
            let slots = plan(
                settings: Fixtures.settings(difficulty: difficulty),
                catalog: catalog,
                now: Fixtures.date(2026, 6, 1, 0, 1)
            )
            XCTAssertEqual(slots.first?.target, expected)
        }
    }

    func testPerExerciseLevelOverridesTheGlobalDifficulty() {
        let catalog = [
            Fixtures.exercise("only", pattern: .core, easy: 3, medium: 9, hard: 27)
        ]
        let slots = plan(
            settings: Fixtures.settings(difficulty: .hard, levels: ["only": .easy]),
            catalog: catalog,
            now: Fixtures.date(2026, 6, 1, 0, 1)
        )
        XCTAssertEqual(slots.first?.target, 3, "exercise_levels beats difficulty")
    }

    func testLastSlotOfTheDayPicksMobilityWhenItIsEligible() {
        // Rule 4c weights mobility at 2x for the closing slot. With no history
        // every pattern is level, so the discount decides it outright.
        let last = Scheduler.pick(
            catalog: Fixtures.smallCatalog,
            settings: Fixtures.settings(),
            history: [],
            at: Fixtures.date(2026, 6, 1, 17, 0),
            localDate: "2026-06-01",
            isFirstOfDay: false,
            isLastOfDay: true,
            seed: 12345
        )
        XCTAssertEqual(last?.pattern, .mobility)
    }

    func testPatternRulesStillOutrankTheMobilityPreference() {
        // Mobility just ran, so 4b removes it and the closing slot has to go
        // elsewhere. The ordering in the spec puts the filters first.
        let previous = Scheduler.plan(
            settings: Fixtures.settings(),
            catalog: Fixtures.smallCatalog,
            now: Fixtures.date(2026, 6, 1, 0, 1),
            deviceID: Fixtures.deviceID
        ).first { $0.pattern == .mobility }
        let history = [XCTUnwrap0(previous)]

        let last = Scheduler.pick(
            catalog: Fixtures.smallCatalog,
            settings: Fixtures.settings(),
            history: history,
            at: history[0].unjitteredAt.addingTimeInterval(3600),
            localDate: history[0].localDate,
            isFirstOfDay: false,
            isLastOfDay: true,
            seed: 12345
        )
        XCTAssertNotEqual(last?.pattern, .mobility)
    }

    func testEveryFullDayIncludesAMobilitySlot() {
        // RESEARCH: any day with four or more prompts should carry at least one
        // mobility item. Partial days at the end of the horizon are exempt.
        for interval in [60, 90, 120] {
            let slots = plan(settings: Fixtures.settings(interval: interval), now: Fixtures.date(2026, 6, 1, 0, 1))
            var byDay: [String: [Pattern]] = [:]
            for slot in slots { byDay[slot.localDate, default: []].append(slot.pattern) }
            let fullDayCount = byDay.values.map(\.count).max() ?? 0
            for (day, patterns) in byDay where patterns.count == fullDayCount && fullDayCount >= 4 {
                XCTAssertTrue(patterns.contains(.mobility), "no mobility on \(day) at \(interval) min")
            }
        }
    }

    func testRecentHistoryCarriesIntoTheNextRun() {
        // Rule 4: reopening the app must not reshuffle what is already queued.
        let settings = Fixtures.settings()
        let firstRun = plan(settings: settings, now: Fixtures.date(2026, 6, 1, 0, 1))
        let cutoff = Fixtures.date(2026, 6, 3, 12, 0)
        let alreadyQueued = firstRun.filter { $0.unjitteredAt <= cutoff }
        let secondRun = plan(settings: settings, now: cutoff, recent: alreadyQueued)

        let overlap = firstRun.filter { $0.unjitteredAt > cutoff }.prefix(5)
        let rescheduled = Dictionary(uniqueKeysWithValues: secondRun.map { ($0.identifier, $0) })
        for slot in overlap {
            XCTAssertEqual(rescheduled[slot.identifier]?.exerciseID, slot.exerciseID)
        }
    }

    // MARK: - Rule 5: copy templates

    func testCopyTemplateIndexStaysInRange() {
        let slots = plan(settings: Fixtures.settings(), now: Fixtures.date(2026, 6, 1, 0, 1))
        for slot in slots {
            XCTAssertGreaterThanOrEqual(slot.copyTemplateIndex, 0)
            XCTAssertLessThan(slot.copyTemplateIndex, slot.intense ? 4 : 3)
        }
    }

    // MARK: - DST

    func testSpringForwardDropsTheMissingHourWithoutDuplicates() {
        // 2026-03-08, America/New_York: 02:00 to 02:59 does not exist.
        let settings = Fixtures.settings(interval: 60, start: 60, end: 360)
        let slots = plan(settings: settings, catalog: Fixtures.smallCatalog, now: Fixtures.date(2026, 3, 8, 0, 1))
        let day = slots.filter { $0.localDate == "2026-03-08" }

        XCTAssertEqual(day.count, 4, "01:00, 03:00, 04:00, 05:00; 02:00 never happens")
        XCTAssertEqual(Set(day.map(\.identifier)).count, day.count)
        XCTAssertEqual(Set(day.map(\.setID)).count, day.count)

        let calendar = Fixtures.calendar(zone)
        let hours = day.map { calendar.component(.hour, from: $0.unjitteredAt) }
        XCTAssertEqual(hours, [1, 3, 4, 5])
    }

    func testFallBackYieldsOneSlotForTheRepeatedHour() {
        // 2026-11-01, America/New_York: 01:00 to 01:59 happens twice.
        let settings = Fixtures.settings(interval: 60, start: 60, end: 360)
        let slots = plan(settings: settings, catalog: Fixtures.smallCatalog, now: Fixtures.date(2026, 11, 1, 0, 1))
        let day = slots.filter { $0.localDate == "2026-11-01" }

        XCTAssertEqual(day.count, 5, "01:00 through 05:00, and the repeated 01:00 counts once")
        XCTAssertEqual(Set(day.map(\.identifier)).count, day.count)
        XCTAssertEqual(Set(day.map(\.unjitteredAt)).count, day.count)

        let calendar = Fixtures.calendar(zone)
        XCTAssertEqual(day.map { calendar.component(.hour, from: $0.unjitteredAt) }, [1, 2, 3, 4, 5])
    }

    func testDstWeekKeepsFiveSlotsADayInTheNormalWindow() {
        // The default 09:00 to 19:00 window is untouched by either transition.
        for (month, day) in [(3, 8), (11, 1)] {
            let slots = plan(settings: Fixtures.settings(), now: Fixtures.date(2026, month, day, 0, 1))
            let today = slots.filter { $0.localDate == String(format: "2026-%02d-%02d", month, day) }
            XCTAssertEqual(today.count, 5, "2026-\(month)-\(day)")
        }
    }

    // MARK: - Rule 8

    func testSetsPerDayLine() {
        XCTAssertEqual(Fixtures.settings().setsPerDay, 5)
        XCTAssertEqual(Fixtures.settings(interval: 60).setsPerDay, 10)
        XCTAssertEqual(Fixtures.settings(interval: 240).setsPerDay, 3)
    }
}
