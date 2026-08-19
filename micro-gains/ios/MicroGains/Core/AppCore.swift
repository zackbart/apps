import Foundation
import UIKit
import UserNotifications

/// The one place that knows how settings, the catalog, the scheduler, the
/// notification queue and the store fit together. Screens and the notification
/// action path both go through here.
///
/// Two signatures the Set screen depends on, spelled out here so they do not
/// drift:
///
///     @discardableResult
///     func log(setID: String, status: SetStatus, reason: SkipReason?, source: SetSource) async -> Bool
///
/// returns false when the slot already held a terminal state (rule 6, first
/// write wins), meaning nothing was recorded and the screen should say so.
///
///     func lowerLevel(for exerciseId: String) -> (newLevel: Difficulty, newTarget: Int)?
///
/// drops one exercise a difficulty step and is only correct to call after `log`
/// came back true. Returns nil when the id is not in the catalog.
@MainActor
final class AppCore {
    static let shared = AppCore()

    let settingsStore = SettingsStore.shared
    let catalog = Catalog.shared
    let store = SetStore.shared
    let sync = SyncCoordinator.shared

    /// Shown in the Settings footer so the user (and I) can see the queue is real.
    private(set) var pendingNotificationCount = 0

    private var timeZoneObserver: NSObjectProtocol?

    var settings: AppSettings {
        get { settingsStore.current }
        set { settingsStore.current = newValue }
    }

    // MARK: - Scheduling

    /// Regenerates the plan and diffs it against the pending queue. Safe to call
    /// on every launch, foreground, settings edit and background refresh.
    @discardableResult
    func reschedule(now: Date = Date()) async -> Int {
        let settings = self.settings
        let catalogItems = catalog.snapshot()

        let recent = await store.recentSlots(before: now)
        let slots = Scheduler.plan(
            settings: settings,
            catalog: catalogItems,
            now: now,
            deviceID: DeviceID.current,
            recent: recent
        )
        // Expiry needs the new plan: a slot only goes stale once the next real
        // slot has come and gone, which with weekends off is Monday.
        await store.expireStale(now: now, intervalMinutes: settings.intervalMinutes, upcoming: slots)
        await store.register(slots: slots)

        let stats = await store.stats(now: now, settings: settings)
        let count = await NotificationPlanner.apply(
            slots: slots,
            catalog: catalogItems,
            streakDays: stats.streakDays,
            enabled: settings.enabled,
            now: now
        )
        pendingNotificationCount = count
        NotificationCenter.default.post(name: .microGainsDataChanged, object: nil)
        return count
    }

    func refreshPendingCount() async {
        pendingNotificationCount = await NotificationPlanner.pendingCount()
    }

    // MARK: - Settings edits

    func update(_ mutate: (inout AppSettings) -> Void) {
        var settings = self.settings
        mutate(&settings)
        self.settings = settings
        Task {
            await sync.pushSettings(settings)
            await reschedule()
        }
    }

    // MARK: - Picking a set on demand

    /// "Do one now" uses the same selection rules as a scheduled slot, seeded
    /// off the current minute so tapping twice does not hand back the same item.
    func pickExerciseNow(now: Date = Date()) async -> (Exercise, Int)? {
        let settings = self.settings
        let items = catalog.snapshot()
        guard !items.isEmpty else { return nil }
        let recent = await store.recentSlots(before: now)
        let seed = Seed.value(DeviceID.current, ISO8601.utc.string(from: now), "manual")
        let localDate = ISO8601.localDate(now, timeZone: settings.timeZone)
        guard let exercise = Scheduler.pick(
            catalog: items,
            settings: settings,
            history: recent,
            at: now,
            localDate: localDate,
            isFirstOfDay: false,
            isLastOfDay: false,
            seed: seed
        ) else { return nil }
        return (exercise, exercise.target(at: settings.level(for: exercise.id)))
    }

    // MARK: - Logging

    /// Returns false when the slot was already answered elsewhere.
    @discardableResult
    func log(
        setID: String,
        status: SetStatus,
        reason: SkipReason? = nil,
        source: SetSource
    ) async -> Bool {
        let settings = self.settings
        let won = await store.log(
            setID: setID,
            status: status,
            reason: reason,
            source: source,
            timeZone: settings.timeZone
        )
        if won {
            NotificationCenter.default.post(name: .microGainsDataChanged, object: nil)
            Task { await sync.flushOutbox() }
        }
        return won
    }

    /// "Too hard" drops that exercise one level and keeps it there. Call it only
    /// after a successful `log`, so a slot that was already answered elsewhere
    /// cannot move the level a second time.
    func lowerLevel(for exerciseId: String) -> (newLevel: Difficulty, newTarget: Int)? {
        guard let exercise = catalog.exercise(id: exerciseId) else { return nil }
        var settings = self.settings
        let newLevel = settings.level(for: exerciseId).eased
        settings.exerciseLevels[exerciseId] = newLevel
        self.settings = settings
        Task {
            await sync.pushSettings(settings)
            await reschedule()
        }
        return (newLevel, exercise.target(at: newLevel))
    }

    /// Same thing with the exercise handed back, for callers that need it.
    @discardableResult
    func easeExercise(id: String) -> (Exercise, Difficulty, Int)? {
        guard let exercise = catalog.exercise(id: id), let change = lowerLevel(for: id) else { return nil }
        return (exercise, change.newLevel, change.newTarget)
    }

    // MARK: - Lifecycle hooks

    /// The device zone is the truth and it moves while the app is asleep. Push
    /// it before replanning, because every slot time is computed in it.
    @discardableResult
    func refreshTimeZone() -> Bool {
        let changed = settingsStore.refreshTimeZone()
        if changed {
            let settings = self.settings
            Task { await sync.pushSettings(settings) }
        }
        return changed
    }

    /// A zone change mid-session (a flight landing, a manual change) has to
    /// rewrite the whole queue, since every slot time is local.
    private func observeTimeZoneChanges() {
        guard timeZoneObserver == nil else { return }
        timeZoneObserver = NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                guard AppCore.shared.refreshTimeZone() else { return }
                Task { await AppCore.shared.reschedule() }
            }
        }
    }

    func onForeground() {
        refreshTimeZone()
        Task {
            await sync.bootstrap()
            await sync.flushSettingsIfNeeded()
            await sync.refreshCatalogIfStale()
            await sync.flushOutbox()
            await reschedule()
        }
    }

    func onLaunch() {
        NotificationPlanner.registerCategory()
        refreshTimeZone()
        observeTimeZoneChanges()
        Task { await refreshPendingCount() }
    }
}
