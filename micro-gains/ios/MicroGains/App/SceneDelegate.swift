import UIKit
import UserNotifications

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .dark
        window.backgroundColor = Theme.background
        window.rootViewController = makeRoot()
        window.makeKeyAndVisible()
        self.window = window

        Router.shared.sceneDelegate = self
        Router.shared.drainPending()

        #if DEBUG
        applyDebugLaunchArguments()
        #endif

        if let response = connectionOptions.notificationResponse {
            let setID = response.notification.request.content
                .userInfo[NotificationPlanner.UserInfoKey.setID] as? String
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                presentSet(setID: setID)
            }
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AppCore.shared.onForeground()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        (UIApplication.shared.delegate as? AppDelegate)?.scheduleBackgroundRefresh()
    }

    #if DEBUG
    /// Screenshot and manual-QA hook. `-mgScreen settings` (and home, history,
    /// set) skips onboarding and opens that screen straight away. Debug only.
    private func applyDebugLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-mgScreen"), index + 1 < arguments.count else { return }
        let screen = arguments[index + 1]

        // onboarding2 through onboarding4 open the intro on a given page.
        if screen.hasPrefix("onboarding") {
            let page = Int(screen.dropFirst("onboarding".count)) ?? 1
            let onboarding = OnboardingViewController { [weak self] in self?.showHome() }
            window?.rootViewController = onboarding
            onboarding.view.layoutIfNeeded()
            for _ in 1..<max(page, 1) { onboarding.advance() }
            return
        }

        AppCore.shared.settingsStore.onboardingCompleted = true
        window?.rootViewController = makeHome()
        guard let navigation = window?.rootViewController as? UINavigationController else { return }

        let seed = arguments.contains("-mgSeed")
        let ask = arguments.contains("-mgAskPermission")
        let simulatedAction = arguments.firstIndex(of: "-mgSimulateAction")
            .flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        Task { @MainActor in
            if seed { await seedSampleHistory() }
            if ask {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
                await AppCore.shared.reschedule()
            }
            if let simulatedAction { await simulateNotificationAction(simulatedAction) }
            switch screen {
            case "settings", "settings-bottom":
                let settings = SettingsViewController()
                navigation.pushViewController(settings, animated: false)
                if screen == "settings-bottom" {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    settings.view.layoutIfNeeded()
                    guard let table = settings.tableView else { break }
                    let bottom = max(table.contentSize.height - table.bounds.height + table.adjustedContentInset.bottom, 0)
                    table.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
                }
            case "history":
                navigation.pushViewController(HistoryViewController(), animated: false)
            case "set":
                await AppCore.shared.reschedule()
                presentSet(setID: nil)
            case "set-timed":
                // Forces a seconds exercise so the countdown ring is on screen.
                await AppCore.shared.reschedule()
                if let exercise = AppCore.shared.catalog.snapshot().first(where: { $0.unit == .seconds }) {
                    let controller = SetViewController(
                        exercise: exercise,
                        target: exercise.target(at: AppCore.shared.settings.difficulty),
                        setID: nil
                    )
                    controller.modalPresentationStyle = .fullScreen
                    navigation.present(controller, animated: false)
                }
            default:
                await AppCore.shared.reschedule()
            }
        }
    }

    /// Runs the real notification action handler against the next pending slot,
    /// so the Done, Skip and Snooze paths can be exercised without a tappable
    /// banner. Debug only.
    private func simulateNotificationAction(_ name: String) async {
        await AppCore.shared.reschedule()
        let pending = await SetStore.shared.allRecords()
            .first { $0.state == .scheduled && $0.slot != nil }
        guard let record = pending, let slot = record.slot else { return }

        let action: String
        switch name {
        case "done": action = NotificationPlanner.doneAction
        case "skip": action = NotificationPlanner.skipAction
        case "snooze": action = NotificationPlanner.snoozeAction
        default: action = UNNotificationDefaultActionIdentifier
        }

        let content = NotificationPlanner.content(
            for: slot,
            catalog: AppCore.shared.catalog.snapshot(),
            streakDays: 0
        )
        guard let delegate = UIApplication.shared.delegate as? AppDelegate else { return }
        await delegate.handle(
            action: action,
            setID: record.setID,
            identifier: slot.identifier,
            content: content
        )
        NSLog("[mg-debug] simulated \(name) on \(record.setID) (\(slot.exerciseID))")
    }

    /// Fills three weeks of plausible sets so screenshots and manual QA are not
    /// staring at zeros. Debug only, and only when -mgSeed is passed.
    private func seedSampleHistory() async {
        let settings = AppCore.shared.settings
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        let catalog = AppCore.shared.catalog.snapshot()
        guard !catalog.isEmpty else { return }

        await SetStore.shared.wipe()
        for dayOffset in stride(from: 20, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let count = [4, 5, 3, 5, 2, 4, 5][dayOffset % 7]
            if dayOffset % 9 == 4 { continue }
            for index in 0..<count {
                let exercise = catalog[(dayOffset * 3 + index) % catalog.count]
                let at = calendar.date(bySettingHour: 9 + index * 2, minute: 5, second: 0, of: day) ?? day
                guard at <= Date() else { continue }
                _ = await SetStore.shared.logManual(
                    exercise: exercise,
                    target: exercise.target(at: settings.difficulty),
                    status: index == 2 && dayOffset % 5 == 0 ? .skipped : .done,
                    reason: index == 2 && dayOffset % 5 == 0 ? .badTime : nil,
                    now: at,
                    timeZone: settings.timeZone
                )
            }
        }
        await AppCore.shared.reschedule()
    }
    #endif

    // MARK: - Root

    func makeRoot() -> UIViewController {
        if AppCore.shared.settingsStore.onboardingCompleted {
            return makeHome()
        }
        return OnboardingViewController { [weak self] in
            self?.showHome()
        }
    }

    private func makeHome() -> UIViewController {
        let navigation = UINavigationController(rootViewController: HomeViewController())
        navigation.navigationBar.prefersLargeTitles = false
        navigation.navigationBar.tintColor = Theme.accent
        navigation.navigationBar.barTintColor = Theme.background
        navigation.view.backgroundColor = Theme.background
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: Theme.text]
        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance
        return navigation
    }

    func showHome() {
        guard let window else { return }
        let home = makeHome()
        if Theme.reduceMotion {
            window.rootViewController = home
            return
        }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = home
        }
    }

    func showOnboarding() {
        guard let window else { return }
        let onboarding = OnboardingViewController { [weak self] in
            self?.showHome()
        }
        if Theme.reduceMotion {
            window.rootViewController = onboarding
            return
        }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = onboarding
        }
    }

    func presentSet(setID: String?) {
        guard let window, let root = window.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        if top is SetViewController { return }

        Task { @MainActor in
            let controller: SetViewController?
            if let setID, let record = await SetStore.shared.record(setID: setID),
               let exercise = AppCore.shared.catalog.exercise(id: record.exerciseID) {
                controller = SetViewController(exercise: exercise, target: record.target, setID: setID)
            } else if let pick = await AppCore.shared.pickExerciseNow() {
                controller = SetViewController(exercise: pick.0, target: pick.1, setID: nil)
            } else {
                controller = nil
            }
            guard let controller else { return }
            controller.modalPresentationStyle = .fullScreen
            top.present(controller, animated: !Theme.reduceMotion)
        }
    }
}
