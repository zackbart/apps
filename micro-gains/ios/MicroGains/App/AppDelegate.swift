import BackgroundTasks
import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    static let backgroundRefreshID = "com.zackbart.microgains.refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // The category has to exist before any notification can be delivered
        // with actions attached, so it goes first.
        UNUserNotificationCenter.current().delegate = self
        AppCore.shared.onLaunch()

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundRefreshID,
            using: nil
        ) { task in
            self.handleRefresh(task: task)
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // MARK: - Background refresh

    /// Best-effort top-up. The 14-day horizon is what actually keeps reminders
    /// flowing, so nothing here is load bearing.
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundRefreshID)
        request.earliestBeginDate = Date().addingTimeInterval(4 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleRefresh(task: BGTask) {
        scheduleBackgroundRefresh()
        let work = Task { @MainActor in
            await AppCore.shared.reschedule()
            await SyncCoordinator.shared.flushOutbox()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }
}

// MARK: - Notification handling

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Banners in the foreground too. The whole point is to interrupt.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if let setID = notification.request.content.userInfo[NotificationPlanner.UserInfoKey.setID] as? String {
            Task { await SetStore.shared.markDelivered(setID: setID) }
        }
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let info = content.userInfo
        let setID = info[NotificationPlanner.UserInfoKey.setID] as? String
        let identifier = info[NotificationPlanner.UserInfoKey.identifier] as? String
            ?? response.notification.request.identifier
        let action = response.actionIdentifier

        // iOS gives an action handler a few seconds. A background task keeps the
        // store write from being cut off half way through.
        let application = UIApplication.shared
        var backgroundTask = UIBackgroundTaskIdentifier.invalid
        backgroundTask = application.beginBackgroundTask(withName: "micro-set-action") {
            application.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }

        // The completion handler is called on every path, including the ones
        // that throw or return early inside the task.
        Task { @MainActor in
            defer {
                if backgroundTask != .invalid {
                    application.endBackgroundTask(backgroundTask)
                    backgroundTask = .invalid
                }
                completionHandler()
            }
            await handle(action: action, setID: setID, identifier: identifier, content: content)
        }
    }

    /// The action routing, split out from the delegate callback so it can be
    /// driven from a test or a debug launch argument. `UNNotificationResponse`
    /// cannot be constructed outside the system.
    @MainActor
    func handle(
        action: String,
        setID: String?,
        identifier: String,
        content: UNNotificationContent
    ) async {
        guard let setID else {
            if action == UNNotificationDefaultActionIdentifier {
                Router.shared.openSet(setID: nil)
            }
            return
        }

        await SetStore.shared.markDelivered(setID: setID)

        switch action {
        case NotificationPlanner.doneAction:
            await AppCore.shared.log(setID: setID, status: .done, source: .notification)
            await AppCore.shared.reschedule()
        case NotificationPlanner.skipAction:
            await AppCore.shared.log(setID: setID, status: .skipped, reason: .badTime, source: .notification)
            await AppCore.shared.reschedule()
        case NotificationPlanner.snoozeAction:
            let fireDate = await NotificationPlanner.snooze(identifier: identifier, content: content)
            await SetStore.shared.markSnoozed(setID: setID, newFireDate: fireDate)
            await AppCore.shared.refreshPendingCount()
        case UNNotificationDefaultActionIdentifier:
            Router.shared.openSet(setID: setID)
        default:
            break
        }
    }
}
