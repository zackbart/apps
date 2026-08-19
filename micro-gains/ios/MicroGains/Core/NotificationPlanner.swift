import Foundation
import UserNotifications

/// Turns `[Slot]` into pending `UNNotificationRequest`s. The reschedule is a
/// diff keyed on the request identifier, so reopening the app never disturbs a
/// reminder that is already queued.
enum NotificationPlanner {
    static let categoryID = "MICRO_SET"
    static let doneAction = "MICRO_SET_DONE"
    static let skipAction = "MICRO_SET_SKIP"
    static let snoozeAction = "MICRO_SET_SNOOZE"
    static let snoozeSuffix = "-snooze"
    static let snoozeInterval: TimeInterval = 10 * 60

    enum UserInfoKey {
        static let exerciseID = "exercise_id"
        static let target = "target"
        static let unit = "unit"
        static let scheduledAt = "scheduled_at"
        static let setID = "set_id"
        static let identifier = "identifier"
        static let fingerprint = "fingerprint"
    }

    /// iOS keeps at most 64 pending local notifications and silently drops the
    /// rest. Regular slots get 60 of those; the remaining 4 are the snooze
    /// headroom (SPEC, Architecture).
    static let maxPending = 64
    static let maxRegular = Scheduler.maxSlots

    /// Registered at launch, before anything else touches the centre.
    static func registerCategory(on center: UNUserNotificationCenter = .current()) {
        let done = UNNotificationAction(identifier: doneAction, title: "Done", options: [])
        let skip = UNNotificationAction(identifier: skipAction, title: "Skip", options: [])
        let snooze = UNNotificationAction(identifier: snoozeAction, title: "Snooze 10 min", options: [])
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [done, skip, snooze],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    // MARK: - Copy (rule 5)

    static func title(for slot: Slot, catalog: [Exercise]) -> String {
        guard let exercise = catalog.first(where: { $0.id == slot.exerciseID }) else {
            return "\(slot.target)"
        }
        return exercise.prescription(target: slot.target)
    }

    /// Identical prompts decay fast, so the body rotates by seed. Index 3 is
    /// reserved for intense cardio.
    static func body(for slot: Slot, catalog: [Exercise], streakDays: Int) -> String {
        let cue = catalog.first(where: { $0.id == slot.exerciseID })?.cue ?? ""
        switch slot.copyTemplateIndex {
        case 1:
            return "\(cue). Set \(slot.indexInDay + 1) of \(slotsInDay(slot)) today"
        case 2 where streakDays > 0:
            return "\(cue). Day \(streakDays)"
        case 3 where slot.intense:
            return "Hard enough that talking is tough"
        default:
            return cue
        }
    }

    private static func slotsInDay(_ slot: Slot) -> Int { max(slot.slotsInDay, slot.indexInDay + 1) }

    static func content(for slot: Slot, catalog: [Exercise], streakDays: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title(for: slot, catalog: catalog)
        content.body = body(for: slot, catalog: catalog, streakDays: streakDays)
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.interruptionLevel = .active
        content.threadIdentifier = "micro-set"
        content.userInfo = [
            UserInfoKey.exerciseID: slot.exerciseID,
            UserInfoKey.target: slot.target,
            UserInfoKey.unit: slot.unit.rawValue,
            UserInfoKey.scheduledAt: ISO8601.utc.string(from: slot.scheduledAt),
            UserInfoKey.setID: slot.setID.uuidString,
            UserInfoKey.identifier: slot.identifier,
            UserInfoKey.fingerprint: slot.contentFingerprint
        ]
        return content
    }

    static func request(for slot: Slot, catalog: [Exercise], streakDays: Int) -> UNNotificationRequest {
        var components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: slot.scheduledAt
        )
        components.timeZone = TimeZone.current
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: slot.identifier, content: content(for: slot, catalog: catalog, streakDays: streakDays), trigger: trigger)
    }

    // MARK: - Diff

    /// One already-queued request, reduced to what the diff needs: its id and
    /// the content fingerprint stashed in `userInfo`. A nil fingerprint is a
    /// request queued by an older build, which is treated as stale.
    struct Pending: Equatable {
        var identifier: String
        var fingerprint: String?

        init(identifier: String, fingerprint: String? = nil) {
            self.identifier = identifier
            self.fingerprint = fingerprint
        }

        init(request: UNNotificationRequest) {
            identifier = request.identifier
            fingerprint = request.content.userInfo[UserInfoKey.fingerprint] as? String
        }

        var isSnooze: Bool { identifier.hasSuffix(snoozeSuffix) }
    }

    struct Diff: Equatable {
        var toRemove: [String]
        var toAdd: [Slot]
        var unchanged: [String]
        /// Queued requests dropped because the budget had no room for them.
        var overBudget: [String] = []
    }

    /// Snoozed copies are left alone: they carry the same set id and the user
    /// asked for them. They do count against the budget, so the number of
    /// regular slots added shrinks by however many snoozes are queued.
    ///
    /// A queued request whose fingerprint no longer matches the slot it stands
    /// for is removed and re-added, so a difficulty or office-mode change
    /// rewrites the reminders that are already in the queue.
    static func diff(
        pending: [Pending],
        against slots: [Slot],
        now: Date,
        budget: Int = maxPending,
        regularBudget: Int = maxRegular
    ) -> Diff {
        let wanted = Dictionary(slots.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
        let snoozes = pending.filter(\.isSnooze)
        let regular = pending.filter { !$0.isSnooze }

        var toRemove: [String] = []
        var keptIdentifiers: [String] = []
        for request in regular {
            guard let slot = wanted[request.identifier] else {
                toRemove.append(request.identifier)
                continue
            }
            if request.fingerprint != slot.contentFingerprint {
                // Same slot, different prescription. Replace it.
                toRemove.append(request.identifier)
            } else {
                keptIdentifiers.append(request.identifier)
            }
        }

        // Room for regular slots: never more than 60, and never more than what
        // the 64-request cap leaves once the snoozes have taken their share.
        let allowance = max(0, min(regularBudget, budget - snoozes.count))

        var kept = keptIdentifiers.compactMap { wanted[$0] }.sorted { $0.scheduledAt < $1.scheduledAt }
        var overBudget: [String] = []
        if kept.count > allowance {
            // The furthest-out reminders lose; the nearest ones are the ones
            // the user is about to see.
            overBudget = kept.suffix(kept.count - allowance).map(\.identifier)
            toRemove.append(contentsOf: overBudget)
            kept = Array(kept.prefix(allowance))
        }

        let keptSet = Set(kept.map(\.identifier))
        let droppedSet = Set(overBudget)
        let toAdd = slots
            .filter { !keptSet.contains($0.identifier) && !droppedSet.contains($0.identifier) }
            .filter { $0.scheduledAt > now }
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .prefix(max(0, allowance - kept.count))
            .map { $0 }

        return Diff(
            toRemove: toRemove,
            toAdd: toAdd,
            unchanged: kept.map(\.identifier),
            overBudget: overBudget
        )
    }

    /// Convenience for callers that only have identifiers (and therefore no
    /// fingerprints) to hand.
    static func diff(pending identifiers: [String], against slots: [Slot], now: Date) -> Diff {
        diff(pending: identifiers.map { Pending(identifier: $0) }, against: slots, now: now)
    }

    // MARK: - Applying

    @discardableResult
    static func apply(
        slots: [Slot],
        catalog: [Exercise],
        streakDays: Int,
        enabled: Bool,
        center: UNUserNotificationCenter = .current(),
        now: Date = Date()
    ) async -> Int {
        // Rule 7: disabled wipes the queue outright.
        guard enabled else {
            center.removeAllPendingNotificationRequests()
            return 0
        }

        let pending = await center.pendingNotificationRequests()
        let diff = diff(pending: pending.map(Pending.init(request:)), against: slots, now: now)

        if !diff.toRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: diff.toRemove)
        }
        for slot in diff.toAdd {
            let request = request(for: slot, catalog: catalog, streakDays: streakDays)
            do {
                try await center.add(request)
            } catch {
                // A refused add means the queue is one reminder short. Nothing
                // to recover here, but silence would hide a real regression.
                NSLog("[MicroGains] could not queue %@: %@", slot.identifier, String(describing: error))
            }
        }
        return await center.pendingNotificationRequests().count
    }

    /// One snooze per slot: the original request is removed and a single
    /// `<id>-snooze` copy is queued ten minutes out with the same set id.
    static func snooze(
        identifier: String,
        content: UNNotificationContent,
        center: UNUserNotificationCenter = .current()
    ) async -> Date {
        let base = identifier.hasSuffix(snoozeSuffix)
            ? String(identifier.dropLast(snoozeSuffix.count))
            : identifier
        center.removePendingNotificationRequests(withIdentifiers: [base, base + snoozeSuffix])

        let fireDate = Date().addingTimeInterval(snoozeInterval)
        let copy = (content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        copy.categoryIdentifier = categoryID
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: snoozeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: base + snoozeSuffix, content: copy, trigger: trigger)
        try? await center.add(request)
        return fireDate
    }

    static func pendingCount(center: UNUserNotificationCenter = .current()) async -> Int {
        await center.pendingNotificationRequests().count
    }
}
