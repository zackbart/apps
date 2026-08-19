import UIKit
import UserNotifications

/// Root screen. One big line about what happens next, today's dots, the streak,
/// and one button.
final class HomeViewController: UIViewController {
    private let nextLabel = Theme.label(font: Theme.title(38), alignment: .center)
    private let todayLabel = Theme.label(font: Theme.body(17), color: Theme.secondaryText, alignment: .center)
    private let dotsView = SlotDotsView()
    private let streakLabel = Theme.label(font: Theme.body(15, weight: .medium), color: Theme.accent, alignment: .center)
    private let doNowButton = Theme.primaryButton("Do one now")
    private let explainerCard = Theme.card()
    private let explainerBody = Theme.label(font: Theme.body(15), color: Theme.secondaryText)
    private lazy var explainerButton = Theme.quietButton("Turn on notifications", color: Theme.accent)
    private let scrollView = UIScrollView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Micro Gains"
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = Theme.background
        buildLayout()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reload),
            name: .microGainsDataChanged,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // The explainer card is what asks for permission, on the first Home
        // appearance rather than at launch.
        Task { await refreshAuthorizationState() }
    }

    // MARK: - Layout

    private func buildLayout() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Settings"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "History",
            style: .plain,
            target: self,
            action: #selector(openHistory)
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = "History"

        doNowButton.addTarget(self, action: #selector(doOneNow), for: .touchUpInside)
        explainerButton.addTarget(self, action: #selector(requestPermission), for: .touchUpInside)

        let explainerTitle = Theme.label(
            "Turn on reminders",
            font: Theme.body(17, weight: .semibold)
        )
        // A plain button, not a second green slab: "Do one now" is the one
        // primary action on this screen.
        explainerButton.contentHorizontalAlignment = .leading
        explainerButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        let explainerStack = Controls.stack([explainerTitle, explainerBody, explainerButton], spacing: 6)
        explainerCard.addSubview(explainerStack)
        explainerCard.isHidden = true
        NSLayoutConstraint.activate([
            explainerStack.topAnchor.constraint(equalTo: explainerCard.topAnchor, constant: 16),
            explainerStack.bottomAnchor.constraint(equalTo: explainerCard.bottomAnchor, constant: -16),
            explainerStack.leadingAnchor.constraint(equalTo: explainerCard.leadingAnchor, constant: 16),
            explainerStack.trailingAnchor.constraint(equalTo: explainerCard.trailingAnchor, constant: -16)
        ])

        let top = Controls.stack([nextLabel, todayLabel, dotsView, streakLabel], spacing: 14)
        top.setCustomSpacing(22, after: nextLabel)
        top.setCustomSpacing(20, after: dotsView)

        // The headline, the dots and the streak scroll; the card and the one
        // button stay put. At accessibility type sizes the top half no longer
        // fits, and pushing the primary action off screen is not an option.
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(top)

        // A stack, so hiding the card leaves no hole above the button.
        let bottom = Controls.stack([explainerCard, doNowButton], spacing: 20)
        view.addSubview(scrollView)
        view.addSubview(bottom)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -24),

            top.topAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            top.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            top.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.sidePadding),
            top.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.sidePadding),
            top.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -Theme.sidePadding * 2),
            top.centerYAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerYAnchor).withPriority(.defaultHigh),

            bottom.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.sidePadding),
            bottom.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.sidePadding),
            bottom.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Data

    @objc private func reload() {
        Task { @MainActor in
            let settings = AppCore.shared.settings
            let now = Date()
            let summary = await AppCore.shared.store.today(now: now, timeZone: settings.timeZone)
            let stats = await AppCore.shared.store.stats(now: now, settings: settings)
            var dots = await todayDots(settings: settings, now: now)
            // "Do one now" sets have no slot behind them. Give each one a
            // green dot so the dots never disagree with the done count.
            let slotDone = dots.filter { $0 == .done }.count
            if summary.done > slotDone {
                dots.append(contentsOf: Array(repeating: SetStore.State.done, count: summary.done - slotDone))
            }

            nextLabel.text = headline(summary: summary, settings: settings, now: now)
            nextLabel.accessibilityLabel = nextLabel.text

            let toGo = dots.filter { !$0.isTerminal }.count
            if dots.isEmpty {
                todayLabel.text = settings.enabled ? "Nothing scheduled today" : "Reminders are paused"
            } else if toGo == 0 && !settings.enabled {
                // Nothing is coming while reminders are off, so "to go" would be
                // a lie next to a "Paused" headline.
                todayLabel.text = summary.done == 1 ? "1 done today" : "\(summary.done) done today"
            } else {
                // Done counts everything logged today, including "Do one now"
                // sets that have no slot behind them. To go counts the dots
                // that are still open.
                todayLabel.text = "\(summary.done) done, \(toGo) to go"
            }
            todayLabel.accessibilityLabel = todayLabel.text

            dotsView.states = dots
            dotsView.isHidden = dots.isEmpty

            // The explainer card has to disappear the moment permission lands,
            // including when the grant happens somewhere other than this screen.
            await refreshAuthorizationState()

            if stats.streakDays > 0 {
                streakLabel.text = "\(stats.streakDays)-day streak"
                streakLabel.accessibilityLabel = streakLabel.text
                streakLabel.isHidden = false
            } else {
                streakLabel.isHidden = true
            }
        }
    }

    /// One dot per slot in today's window, including the ones that have already
    /// been and gone. Slots the store never saw are shown as expired, which is
    /// what a day that started before the app was installed looks like.
    private func todayDots(settings: AppSettings, now: Date) async -> [SetStore.State] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        let times = Scheduler.dayTimes(
            settings: settings,
            day: calendar.startOfDay(for: now),
            calendar: calendar
        )
        guard !times.isEmpty else { return [] }

        let ids = times.map { Scheduler.setID(for: Scheduler.identifier(for: $0)).uuidString }
        let known = await AppCore.shared.store.records(setIDs: ids)
        return zip(times, ids).map { time, id in
            if let record = known[id] { return record.state }
            guard time > now else { return .expired }
            // A slot that pausing has taken off the table is not "still coming".
            guard settings.enabled else { return .expired }
            if let until = settings.pausedUntil, time < until { return .expired }
            return .scheduled
        }
    }

    private func headline(summary: SetStore.TodaySummary, settings: AppSettings, now: Date) -> String {
        guard settings.enabled else { return "Paused" }
        if let pausedUntil = settings.pausedUntil, pausedUntil > now {
            return "Paused until \(Theme.timeString(pausedUntil, timeZone: settings.timeZone))"
        }
        if let next = summary.nextAt {
            return "Next set at \(Theme.timeString(next, timeZone: settings.timeZone))"
        }
        return "Done for today"
    }

    private func refreshAuthorizationState() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let settings = AppCore.shared.settings
        switch status {
        case .notDetermined:
            explainerBody.text = "Micro Gains only works if it can ping you. "
                + Controls.setsPerDayLine(settings) + " with your current settings."
            setExplainerButtonTitle("Turn on notifications")
            explainerCard.isHidden = false
        case .denied:
            explainerBody.text = "Notifications are off, so nothing will ping you. Turn them on in iOS Settings."
            setExplainerButtonTitle("Open Settings")
            explainerCard.isHidden = false
        default:
            explainerCard.isHidden = true
        }
    }

    private func setExplainerButtonTitle(_ title: String) {
        explainerButton.configuration?.title = title
        explainerButton.accessibilityLabel = title
        explainerButton.setNeedsUpdateConfiguration()
    }

    // MARK: - Actions

    @objc private func requestPermission() {
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            if status == .denied {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    await UIApplication.shared.open(url)
                }
                return
            }
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            AppCore.shared.settingsStore.permissionExplainerShown = true
            await AppCore.shared.reschedule()
            await refreshAuthorizationState()
        }
    }

    @objc private func doOneNow() {
        Task { @MainActor in
            guard let pick = await AppCore.shared.pickExerciseNow() else { return }
            let controller = SetViewController(exercise: pick.0, target: pick.1, setID: nil)
            controller.modalPresentationStyle = .fullScreen
            present(controller, animated: !Theme.reduceMotion)
        }
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    @objc private func openHistory() {
        navigationController?.pushViewController(HistoryViewController(), animated: true)
    }
}

/// One dot per slot in today's window. Filled green is done, hollow is still
/// coming, dim is skipped or expired. No red, no crosses; a missed set is not a
/// debt. Drawn rather than stacked so a 24 hour window at a one hour interval
/// wraps onto a second row instead of running off the screen.
final class SlotDotsView: UIView {
    var states: [SetStore.State] = [] {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
            let done = states.filter { $0 == .done }.count
            accessibilityLabel = "\(done) of \(states.count) sets done today"
        }
    }

    private let diameter: CGFloat = 12
    private let gap: CGFloat = 10
    private var lastWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override var intrinsicContentSize: CGSize {
        guard !states.isEmpty else { return CGSize(width: UIView.noIntrinsicMetric, height: 0) }
        let rows = CGFloat(rowCount(width: lastWidth))
        return CGSize(width: UIView.noIntrinsicMetric, height: rows * diameter + (rows - 1) * gap)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard abs(bounds.width - lastWidth) > 0.5 else { return }
        lastWidth = bounds.width
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    private func perRow(width: CGFloat) -> Int {
        guard width > diameter else { return max(states.count, 1) }
        let fits = Int((width + gap) / (diameter + gap))
        return max(1, min(fits, states.count))
    }

    private func rowCount(width: CGFloat) -> Int {
        guard !states.isEmpty else { return 0 }
        let per = perRow(width: width)
        return (states.count + per - 1) / per
    }

    override func draw(_ rect: CGRect) {
        guard !states.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }
        let per = perRow(width: rect.width)
        for (index, state) in states.enumerated() {
            let row = index / per
            let column = index % per
            let inRow = min(per, states.count - row * per)
            let rowWidth = CGFloat(inRow) * diameter + CGFloat(inRow - 1) * gap
            let box = CGRect(
                x: (rect.width - rowWidth) / 2 + CGFloat(column) * (diameter + gap),
                y: CGFloat(row) * (diameter + gap),
                width: diameter,
                height: diameter
            )
            switch state {
            case .done:
                context.setFillColor(Theme.accent.cgColor)
                context.fillEllipse(in: box)
            case .skipped, .expired:
                context.setFillColor(UIColor(white: 1, alpha: 0.16).cgColor)
                context.fillEllipse(in: box)
            case .scheduled, .delivered:
                context.setStrokeColor(Theme.green.cgColor)
                context.setLineWidth(2)
                context.strokeEllipse(in: box.insetBy(dx: 1, dy: 1))
            }
        }
    }
}
