import Foundation

/// The slot and set log. One JSON file in Application Support, one actor, so
/// the app and the notification action path cannot interleave writes.
actor SetStore {
    static let shared = SetStore()

    enum State: String, Codable, Sendable {
        case scheduled, delivered, done, skipped, expired

        var isTerminal: Bool {
            self == .done || self == .skipped || self == .expired
        }
    }

    struct Record: Codable, Equatable, Sendable {
        var setID: String
        var slot: Slot?
        var exerciseID: String
        var target: Int
        var unit: SetUnit
        /// The slot's planned delivery time. Immutable once written: it is what
        /// goes to the server as `scheduled_at`, and a snooze must not rewrite
        /// history.
        var scheduledAt: Date?
        var state: State
        var snoozed: Bool
        /// When a snoozed slot will fire again. Only set while `snoozed`.
        var snoozedUntil: Date?
        var skipReason: SkipReason?
        var loggedAt: Date?
        var localDate: String?
        var source: SetSource
        var synced: Bool
        /// Failed outbox attempts. The set is dropped after `maxSyncAttempts`.
        var syncAttempts: Int?

        /// When this slot is next expected to fire: the snooze time if it has
        /// one, its scheduled time otherwise.
        var dueAt: Date? {
            guard let scheduledAt else { return snoozedUntil }
            guard let snoozedUntil else { return scheduledAt }
            return max(scheduledAt, snoozedUntil)
        }

        var setLog: SetLog? {
            guard let loggedAt, let localDate else { return nil }
            let status: SetStatus
            switch state {
            case .done: status = .done
            case .skipped: status = .skipped
            default: return nil
            }
            return SetLog(
                id: setID,
                exerciseID: exerciseID,
                target: target,
                unit: unit,
                status: status,
                skipReason: skipReason,
                scheduledAt: scheduledAt,
                loggedAt: loggedAt,
                localDate: localDate,
                source: source
            )
        }
    }

    private let fileURL: URL
    private var records: [String: Record] = [:]
    private var loaded = false
    /// Records older than this are dropped on save. History only goes back 30 days.
    private let retention: TimeInterval = 120 * 24 * 3600

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? AppPaths.applicationSupport.appendingPathComponent("sets.json")
    }

    // MARK: - Persistence

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? SettingsStore.decoder.decode([Record].self, from: data)
        else { return }
        records = Dictionary(uniqueKeysWithValues: decoded.map { ($0.setID, $0) })
    }

    private func save() {
        let cutoff = Date().addingTimeInterval(-retention)
        let kept = records.values.filter { record in
            let stamp = record.loggedAt ?? record.scheduledAt ?? Date()
            // Unsynced logs are never pruned; they still owe the server a write.
            return stamp > cutoff || (record.state.isTerminal && !record.synced)
        }
        records = Dictionary(uniqueKeysWithValues: kept.map { ($0.setID, $0) })
        guard let data = try? SettingsStore.encoder.encode(kept.sorted { lhs, rhs in
            (lhs.scheduledAt ?? lhs.loggedAt ?? .distantPast) < (rhs.scheduledAt ?? rhs.loggedAt ?? .distantPast)
        }) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Slot lifecycle

    /// Adds records for slots we have not seen. Existing records keep their
    /// state, so re-planning never resurrects a finished slot.
    ///
    /// A slot that is still `scheduled` is updated in place when the plan
    /// repicked its exercise or target (a difficulty or office-mode change does
    /// that), keeping the set id so the queued notification and the record stay
    /// on the same slot. Delivered and terminal records are left alone: the user
    /// has already seen or answered them.
    func register(slots: [Slot]) {
        load()
        var changed = false
        for slot in slots {
            let key = slot.setID.uuidString
            guard var existing = records[key] else {
                records[key] = Record(
                    setID: key,
                    slot: slot,
                    exerciseID: slot.exerciseID,
                    target: slot.target,
                    unit: slot.unit,
                    scheduledAt: slot.scheduledAt,
                    state: .scheduled,
                    snoozed: false,
                    snoozedUntil: nil,
                    skipReason: nil,
                    loggedAt: nil,
                    localDate: slot.localDate,
                    source: .notification,
                    synced: false,
                    syncAttempts: nil
                )
                changed = true
                continue
            }
            guard existing.state == .scheduled else { continue }
            let samePrescription = existing.exerciseID == slot.exerciseID
                && existing.target == slot.target
                && existing.unit == slot.unit
                && existing.scheduledAt == slot.scheduledAt
                && existing.slot?.contentFingerprint == slot.contentFingerprint
            guard !samePrescription else { continue }
            existing.slot = slot
            existing.exerciseID = slot.exerciseID
            existing.target = slot.target
            existing.unit = slot.unit
            existing.scheduledAt = slot.scheduledAt
            existing.localDate = slot.localDate
            records[key] = existing
            changed = true
        }
        if changed { save() }
    }

    func markDelivered(setID: String) {
        load()
        guard var record = records[setID], record.state == .scheduled else { return }
        record.state = .delivered
        records[setID] = record
        save()
    }

    /// `scheduledAt` stays put: it is the slot the server logged and the one the
    /// expiry rule counts from. The new fire time lands in `snoozedUntil`.
    func markSnoozed(setID: String, newFireDate: Date) {
        load()
        guard var record = records[setID], !record.state.isTerminal else { return }
        record.snoozed = true
        record.state = .delivered
        record.snoozedUntil = newFireDate
        records[setID] = record
        save()
    }

    /// Rule 6: the first terminal write wins. Returns false when the slot was
    /// already answered, so the caller can tell the user nothing happened.
    @discardableResult
    func log(
        setID: String,
        status: SetStatus,
        reason: SkipReason? = nil,
        source: SetSource,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> Bool {
        load()
        guard var record = records[setID] else { return false }
        guard !record.state.isTerminal else { return false }
        record.state = status == .done ? .done : .skipped
        record.skipReason = status == .skipped ? reason : nil
        record.loggedAt = now
        record.localDate = ISO8601.localDate(now, timeZone: timeZone)
        record.source = source
        record.synced = false
        records[setID] = record
        save()
        return true
    }

    /// "Do one now": a set with no slot behind it.
    @discardableResult
    func logManual(
        exercise: Exercise,
        target: Int,
        status: SetStatus,
        reason: SkipReason? = nil,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        load()
        let id = UUID().uuidString.lowercased()
        records[id] = Record(
            setID: id,
            slot: nil,
            exerciseID: exercise.id,
            target: target,
            unit: exercise.unit,
            scheduledAt: nil,
            state: status == .done ? .done : .skipped,
            snoozed: false,
            snoozedUntil: nil,
            skipReason: status == .skipped ? reason : nil,
            loggedAt: now,
            localDate: ISO8601.localDate(now, timeZone: timeZone),
            source: .app,
            synced: false,
            syncAttempts: nil
        )
        save()
        return id
    }

    /// Rule 6: a slot with no answer by the time the *next actual slot* is due
    /// expires. Not a skip, never shown as a failure.
    ///
    /// The next slot matters rather than the raw interval: with weekends off,
    /// Friday's last set is still answerable all weekend, because the next slot
    /// is Monday morning. `upcoming` is the freshly generated plan; the times of
    /// the slots already on file fill in the gap between now and then. Only when
    /// no later slot exists at all does this fall back to interval plus grace.
    func expireStale(now: Date, intervalMinutes: Int, upcoming: [Slot] = []) {
        load()
        let grace = TimeInterval(max(intervalMinutes, 1) * 60)

        var times = Set(records.values.compactMap(\.dueAt))
        for slot in upcoming { times.insert(slot.scheduledAt) }
        let ordered = times.sorted()

        var changed = false
        for (key, var record) in records {
            guard !record.state.isTerminal, let due = record.dueAt else { continue }
            let expired: Bool
            if let next = ordered.first(where: { $0 > due }) {
                expired = next <= now
            } else {
                expired = due.addingTimeInterval(grace) < now
            }
            guard expired else { continue }
            record.state = .expired
            records[key] = record
            changed = true
        }
        if changed { save() }
    }

    // MARK: - Reads

    func record(setID: String) -> Record? {
        load()
        return records[setID]
    }

    func records(setIDs: [String]) -> [String: Record] {
        load()
        var found: [String: Record] = [:]
        for id in setIDs {
            if let record = records[id] { found[id] = record }
        }
        return found
    }

    /// Slot history for the scheduler's rules 4b through 4d, newest last.
    func recentSlots(before date: Date, limit: Int = 40) -> [Slot] {
        load()
        return records.values
            .compactMap(\.slot)
            .filter { $0.unjitteredAt <= date }
            .sorted { $0.unjitteredAt < $1.unjitteredAt }
            .suffix(limit)
            .map { $0 }
    }

    func allRecords() -> [Record] {
        load()
        return records.values.sorted {
            ($0.scheduledAt ?? $0.loggedAt ?? .distantPast) < ($1.scheduledAt ?? $1.loggedAt ?? .distantPast)
        }
    }

    func outbox(limit: Int = 200) -> [SetLog] {
        load()
        return records.values
            .filter { !$0.synced }
            .compactMap(\.setLog)
            .sorted { $0.loggedAt < $1.loggedAt }
            .prefix(limit)
            .map { $0 }
    }

    /// A set the server refused for a reason that might not repeat gets this
    /// many tries before the device stops offering it. Otherwise one poisoned
    /// row would wedge the outbox forever.
    static let maxSyncAttempts = 5

    func markSynced(ids: [String]) {
        load()
        var changed = false
        for id in ids {
            guard var record = records[id], !record.synced else { continue }
            record.synced = true
            record.syncAttempts = nil
            records[id] = record
            changed = true
        }
        if changed { save() }
    }

    /// Counts one failed attempt against each id and gives up on the ones that
    /// have run out of tries. Returns the ids it stopped retrying.
    @discardableResult
    func markSyncRetry(ids: [String], maxAttempts: Int = SetStore.maxSyncAttempts) -> [String] {
        load()
        var abandoned: [String] = []
        var changed = false
        for id in ids {
            guard var record = records[id], !record.synced else { continue }
            let attempts = (record.syncAttempts ?? 0) + 1
            record.syncAttempts = attempts
            if attempts >= maxAttempts {
                record.synced = true
                abandoned.append(id)
            }
            records[id] = record
            changed = true
        }
        if changed { save() }
        return abandoned
    }

    func syncAttempts(setID: String) -> Int {
        load()
        return records[setID]?.syncAttempts ?? 0
    }

    func wipe() {
        load()
        records = [:]
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Derived

    struct TodaySummary: Sendable, Equatable {
        var done: Int
        var skipped: Int
        var remaining: Int
        /// One entry per slot in today's window, in time order.
        var dots: [State]
        var nextAt: Date?
        var nextSetID: String?
    }

    func today(now: Date, timeZone: TimeZone) -> TodaySummary {
        load()
        let localDate = ISO8601.localDate(now, timeZone: timeZone)
        let todays = records.values
            .filter { $0.localDate == localDate }
            .sorted { ($0.scheduledAt ?? $0.loggedAt ?? .distantPast) < ($1.scheduledAt ?? $1.loggedAt ?? .distantPast) }

        let done = todays.filter { $0.state == .done }.count
        let skipped = todays.filter { $0.state == .skipped }.count
        let remaining = todays.filter { !$0.state.isTerminal }.count
        // A snoozed slot counts by the time it will actually fire.
        let next = todays.first { !$0.state.isTerminal && ($0.dueAt ?? .distantPast) > now }
        return TodaySummary(
            done: done,
            skipped: skipped,
            remaining: remaining,
            dots: todays.map(\.state),
            nextAt: next?.dueAt,
            nextSetID: next?.setID
        )
    }

    func history(days: Int, now: Date, timeZone: TimeZone) -> [HistoryDay] {
        load()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var buckets: [String: HistoryDay] = [:]
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let key = ISO8601.localDate(date, timeZone: timeZone)
            buckets[key] = HistoryDay(date: key, done: 0, skipped: 0, reps: 0, seconds: 0)
        }

        for record in records.values {
            guard let key = record.localDate, var bucket = buckets[key] else { continue }
            switch record.state {
            case .done:
                bucket.done += 1
                if record.unit == .reps { bucket.reps += record.target } else { bucket.seconds += record.target }
            case .skipped:
                bucket.skipped += 1
            default:
                continue
            }
            buckets[key] = bucket
        }
        return buckets.values.sorted { $0.date < $1.date }
    }

    func stats(now: Date, settings: AppSettings) -> Stats {
        load()
        let timeZone = settings.timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let todayKey = ISO8601.localDate(now, timeZone: timeZone)
        var doneByDay: [String: Int] = [:]
        var totalDone = 0
        var totalReps = 0
        var totalSeconds = 0
        var todayDone = 0
        var todaySkipped = 0

        for record in records.values {
            guard let key = record.localDate else { continue }
            switch record.state {
            case .done:
                doneByDay[key, default: 0] += 1
                totalDone += 1
                if record.unit == .reps { totalReps += record.target } else { totalSeconds += record.target }
                if key == todayKey { todayDone += 1 }
            case .skipped:
                if key == todayKey { todaySkipped += 1 }
            default:
                continue
            }
        }

        let (streak, best) = Self.streaks(
            doneByDay: doneByDay,
            now: now,
            settings: settings,
            calendar: calendar
        )
        return Stats(
            todayDone: todayDone,
            todaySkipped: todaySkipped,
            streakDays: streak,
            bestStreakDays: best,
            totalDone: totalDone,
            totalReps: totalReps,
            totalSeconds: totalSeconds
        )
    }

    /// Consecutive active days with at least one done set. Rest days are
    /// transparent: they neither break the streak nor extend it.
    static func streaks(
        doneByDay: [String: Int],
        now: Date,
        settings: AppSettings,
        calendar: Calendar
    ) -> (current: Int, best: Int) {
        guard settings.activeDayCount > 0 else { return (0, 0) }

        var current = 0
        var cursor = calendar.startOfDay(for: now)
        var scannedActiveDays = 0
        // Walk back a year at most.
        for _ in 0..<400 {
            let weekdayIndex = (calendar.component(.weekday, from: cursor) + 5) % 7
            if settings.isActive(weekdayIndex: weekdayIndex) {
                let key = ISO8601.localDate(cursor, timeZone: settings.timeZone)
                if (doneByDay[key] ?? 0) > 0 {
                    current += 1
                } else if scannedActiveDays > 0 || key != ISO8601.localDate(now, timeZone: settings.timeZone) {
                    // Today counts only once it has a set; an empty today does
                    // not end a streak that ran through yesterday.
                    break
                }
                scannedActiveDays += 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        // Best streak: same rule, scanned forward over the recorded days.
        let sortedKeys = doneByDay.filter { $0.value > 0 }.keys.sorted()
        var best = current
        var run = 0
        var previousKey: String?
        for key in sortedKeys {
            if let previousKey, !Self.areConsecutiveActiveDays(previousKey, key, settings: settings, calendar: calendar) {
                run = 0
            }
            run += 1
            best = max(best, run)
            previousKey = key
        }
        return (current, best)
    }

    private static func areConsecutiveActiveDays(
        _ earlier: String,
        _ later: String,
        settings: AppSettings,
        calendar: Calendar
    ) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = settings.timeZone
        guard let start = formatter.date(from: earlier), let end = formatter.date(from: later) else { return false }
        var cursor = start
        while cursor < end {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { return false }
            cursor = next
            if cursor >= end { return true }
            let weekdayIndex = (calendar.component(.weekday, from: cursor) + 5) % 7
            // A skipped active day in between breaks the run; a rest day does not.
            if settings.isActive(weekdayIndex: weekdayIndex) { return false }
        }
        return true
    }
}
