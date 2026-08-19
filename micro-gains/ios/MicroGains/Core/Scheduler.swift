import Foundation

/// One prescribed set at one point in time. Everything the notification and the
/// Set screen need, and nothing that depends on UIKit.
struct Slot: Equatable, Codable, Sendable {
    /// "slot-<unjittered time as ISO8601 UTC>". The notification request id.
    let identifier: String
    /// UUID v5 of `identifier`, so the same slot always logs the same set id.
    let setID: UUID
    let unjitteredAt: Date
    let scheduledAt: Date
    let exerciseID: String
    let pattern: Pattern
    let target: Int
    let unit: SetUnit
    /// Which body template rule 5 should use.
    let copyTemplateIndex: Int
    let indexInDay: Int
    let slotsInDay: Int
    let isLastOfDay: Bool
    let localDate: String
    let intense: Bool

    var isFirstOfDay: Bool { indexInDay == 0 }

    /// Everything the notification actually shows. Two slots can share an
    /// identifier and still differ here (a difficulty or office-mode change
    /// repicks the exercise and the target), which is what tells the planner a
    /// queued request is stale and has to be replaced rather than left alone.
    var contentFingerprint: String {
        "\(exerciseID)|\(target)|\(unit.rawValue)|\(copyTemplateIndex)"
    }
}

/// Pure slot generation. No UIKit, no UserNotifications, no singletons, no
/// clock reads. Everything it needs arrives as an argument, which is what makes
/// the DST and determinism tests possible.
enum Scheduler {
    /// iOS caps pending local notifications at 64. Four are held back for snoozes.
    static let maxSlots = 60
    static let horizonDays = 14
    static let jitterMinutes = 5
    /// Rule 4b: two sets of one pattern must be at least this far apart.
    static let patternCooldown: TimeInterval = 3 * 3600
    static let sameExerciseCooldown: TimeInterval = 24 * 3600

    static func plan(
        settings: AppSettings,
        catalog: [Exercise],
        now: Date,
        deviceID: String,
        recent: [Slot] = []
    ) -> [Slot] {
        // Rule 7: paused means no pipeline at all.
        guard settings.enabled, !catalog.isEmpty else { return [] }
        guard settings.intervalMinutes > 0,
              settings.activeEndMinute > settings.activeStartMinute else { return [] }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone

        var history = recent.sorted { $0.unjitteredAt < $1.unjitteredAt }
        var slots: [Slot] = []

        let today = calendar.startOfDay(for: now)
        var dayOffset = 0

        while dayOffset < horizonDays && slots.count < maxSlots {
            defer { dayOffset += 1 }
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            // Monday = 0 to match the active_days bit mask.
            let weekdayIndex = (calendar.component(.weekday, from: day) + 5) % 7
            guard settings.isActive(weekdayIndex: weekdayIndex) else { continue }

            // Build the whole day first so "Set 3 of 6 today" counts the day,
            // not the part of it that is still ahead of us.
            let dayTimes = dayTimes(settings: settings, day: day, calendar: calendar)
            guard !dayTimes.isEmpty else { continue }

            let localDate = ISO8601.localDate(day, timeZone: settings.timeZone)
            let windowStart = wallClock(day: day, minuteOfDay: settings.activeStartMinute, calendar: calendar)
                ?? dayTimes[0]
            let windowEnd = wallClock(day: day, minuteOfDay: settings.activeEndMinute, calendar: calendar)
                ?? dayTimes[dayTimes.count - 1].addingTimeInterval(60)

            for (index, unjittered) in dayTimes.enumerated() {
                guard slots.count < maxSlots else { break }
                // Rule 1: start with the first slot strictly after now.
                guard unjittered > now else { continue }
                // Rule 7: keep the pipeline but skip anything before paused_until.
                if let pausedUntil = settings.pausedUntil, unjittered < pausedUntil { continue }

                let identifier = identifier(for: unjittered)
                let seed = Seed.value(deviceID, identifier)

                let scheduledAt = jitter(
                    unjittered,
                    seed: seed,
                    previous: index > 0 ? dayTimes[index - 1] : nil,
                    next: index + 1 < dayTimes.count ? dayTimes[index + 1] : nil,
                    windowStart: windowStart,
                    windowEnd: windowEnd
                )

                let choice = pick(
                    catalog: catalog,
                    settings: settings,
                    history: history,
                    at: unjittered,
                    localDate: localDate,
                    isFirstOfDay: index == 0,
                    isLastOfDay: index == dayTimes.count - 1,
                    seed: seed
                )
                guard let exercise = choice else { continue }

                let level = settings.level(for: exercise.id)
                let templateSeed = Seed.value(deviceID, identifier, "copy")
                let templateCount = exercise.intense ? 4 : 3

                let slot = Slot(
                    identifier: identifier,
                    setID: setID(for: identifier),
                    unjitteredAt: unjittered,
                    scheduledAt: scheduledAt,
                    exerciseID: exercise.id,
                    pattern: exercise.pattern,
                    target: exercise.target(at: level),
                    unit: exercise.unit,
                    copyTemplateIndex: Seed.index(templateSeed, upperBound: templateCount),
                    indexInDay: index,
                    slotsInDay: dayTimes.count,
                    isLastOfDay: index == dayTimes.count - 1,
                    localDate: localDate,
                    intense: exercise.intense
                )
                slots.append(slot)
                history.append(slot)
            }
        }

        return slots
    }

    // MARK: - Identity

    /// Rule 3: the request identifier keys off the unjittered time only, so the
    /// same slot has the same id no matter when the plan was rebuilt.
    static func identifier(for unjittered: Date) -> String {
        "slot-" + ISO8601.utc.string(from: unjittered)
    }

    static func setID(for identifier: String) -> UUID {
        UUIDv5.make(namespace: UUIDv5.slotNamespace, name: identifier)
    }

    // MARK: - Time

    /// Every unjittered slot time on one local day, whether or not it has passed.
    /// Home needs the whole day to draw one dot per slot.
    static func dayTimes(settings: AppSettings, day: Date, calendar: Calendar) -> [Date] {
        guard settings.intervalMinutes > 0, settings.activeEndMinute > settings.activeStartMinute else { return [] }
        let weekdayIndex = (calendar.component(.weekday, from: day) + 5) % 7
        guard settings.isActive(weekdayIndex: weekdayIndex) else { return [] }

        var times: [Date] = []
        var minute = settings.activeStartMinute
        while minute < settings.activeEndMinute {
            if let date = wallClock(day: day, minuteOfDay: minute, calendar: calendar) {
                times.append(date)
            }
            minute += settings.intervalMinutes
        }
        return times
    }

    /// The instant of `minuteOfDay` local time on `day`, or nil when that wall
    /// clock time does not exist (the spring-forward gap). A repeated hour in
    /// the autumn resolves to its first occurrence, so it yields one slot.
    static func wallClock(day: Date, minuteOfDay: Int, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        components.second = 0
        guard let date = calendar.date(from: components) else { return nil }
        let roundTrip = calendar.dateComponents([.hour, .minute], from: date)
        guard roundTrip.hour == components.hour, roundTrip.minute == components.minute else {
            return nil
        }
        return date
    }

    /// Rule 2: a deterministic offset in [-5, +5] minutes, clamped so the slot
    /// stays inside the active window and never crosses a neighbour.
    static func jitter(
        _ unjittered: Date,
        seed: UInt64,
        previous: Date?,
        next: Date?,
        windowStart: Date,
        windowEnd: Date
    ) -> Date {
        let span = jitterMinutes * 2 + 1
        let offset = Int(seed % UInt64(span)) - jitterMinutes
        var result = unjittered.addingTimeInterval(Double(offset) * 60)

        var lower = windowStart
        var upper = windowEnd.addingTimeInterval(-60)
        if let previous { lower = max(lower, previous.addingTimeInterval(60)) }
        if let next { upper = min(upper, next.addingTimeInterval(-60)) }
        if upper < lower { return unjittered }

        result = min(max(result, lower), upper)
        return result
    }

    // MARK: - Exercise selection (rule 4)

    static func pick(
        catalog: [Exercise],
        settings: AppSettings,
        history: [Slot],
        at time: Date,
        localDate: String,
        isFirstOfDay: Bool,
        isLastOfDay: Bool,
        seed: UInt64
    ) -> Exercise? {
        // 4a. Filters, dropped wholesale if they leave nothing.
        var eligible = catalog.filter { exercise in
            if settings.officeMode && !exercise.officeOk { return false }
            if !settings.floorOk && exercise.needsFloor { return false }
            return true
        }
        if eligible.isEmpty { eligible = catalog }
        guard !eligible.isEmpty else { return nil }

        // 4b. Pattern constraints, relaxed last-applied-first.
        let previousPattern = history.last?.pattern
        var dayCounts: [Pattern: Int] = [:]
        for slot in history where slot.localDate == localDate {
            dayCounts[slot.pattern, default: 0] += 1
        }
        let cooldownCutoff = time.addingTimeInterval(-patternCooldown)
        let recentPatterns = Set(
            history.filter { $0.unjitteredAt > cooldownCutoff }.map(\.pattern)
        )

        var patterns = Set(eligible.map(\.pattern))
        var relaxed = patterns
        relaxed = patterns.filter { !recentPatterns.contains($0) }
        if relaxed.isEmpty { relaxed = patterns }
        patterns = relaxed

        relaxed = patterns.filter { (dayCounts[$0] ?? 0) < 2 }
        if relaxed.isEmpty { relaxed = patterns }
        patterns = relaxed

        relaxed = patterns.filter { $0 != previousPattern }
        if relaxed.isEmpty { relaxed = patterns }
        patterns = relaxed

        var candidates = eligible.filter { patterns.contains($0.pattern) }

        // 4c. No intense cardio as the first set of the day. There is no warm-up
        // in this product.
        if isFirstOfDay {
            let calm = candidates.filter { !$0.intense }
            if !calm.isEmpty { candidates = calm }
        }
        guard !candidates.isEmpty else { return nil }

        // 4d. Prefer the pattern used least across the last 6 generated slots.
        // The last slot of the day weights mobility at 2x. In a deterministic
        // argmin that reads as a one-use discount plus first place in the tie
        // break, so mobility closes the day whenever it is still eligible.
        let window = history.suffix(6)
        var scores: [Pattern: Double] = [:]
        for pattern in Set(candidates.map(\.pattern)) {
            var score = Double(window.filter { $0.pattern == pattern }.count)
            if isLastOfDay && pattern == .mobility { score -= 1 }
            scores[pattern] = score
        }
        let best = scores.values.min() ?? 0
        var tied = scores.filter { $0.value == best }.keys.sorted { $0.rawValue < $1.rawValue }
        let pattern: Pattern
        if isLastOfDay, tied.contains(.mobility) {
            pattern = .mobility
        } else {
            if isLastOfDay { tied = tied.filter { $0 != .mobility } }
            pattern = tied[Seed.index(seed, upperBound: tied.count)]
        }

        var withinPattern = candidates.filter { $0.pattern == pattern }

        // 4d continued: avoid the last two exercises and anything from the last
        // 24 h of slots, but only while more than one candidate survives.
        if withinPattern.count > 1 {
            let lastTwo = Set(history.suffix(2).map(\.exerciseID))
            let dayCutoff = time.addingTimeInterval(-sameExerciseCooldown)
            let recentIDs = Set(history.filter { $0.unjitteredAt > dayCutoff }.map(\.exerciseID))
            let fresh = withinPattern.filter { !lastTwo.contains($0.id) && !recentIDs.contains($0.id) }
            if !fresh.isEmpty {
                withinPattern = fresh
            } else {
                let notJustUsed = withinPattern.filter { !lastTwo.contains($0.id) }
                if !notJustUsed.isEmpty { withinPattern = notJustUsed }
            }
        }

        let ordered = withinPattern.sorted { $0.id < $1.id }
        let pickSeed = Seed.value(String(seed), "exercise")
        return ordered[Seed.index(pickSeed, upperBound: ordered.count)]
    }
}
