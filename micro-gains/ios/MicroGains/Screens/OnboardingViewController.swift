import UIKit
import UserNotifications

/// Four pages, one idea each, completable in under thirty seconds. Swipe or tap
/// Continue. Finishing writes settings, fills the notification queue and hands
/// over to Home.
final class OnboardingViewController: UIViewController {
    private let onFinish: () -> Void
    private var settings = AppSettings.default

    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let nextButton = Theme.primaryButton("Continue")
    private let skipButton = Theme.quietButton("Skip")
    private var bottomStack = UIStackView()

    private let setsPerDayLabel = Theme.label(font: Theme.body(17, weight: .semibold), color: Theme.accent, alignment: .center)
    private let difficultyExampleLabel = Theme.label(font: Theme.body(15), color: Theme.secondaryText, alignment: .center)
    private let permissionNoteLabel = Theme.label(font: Theme.body(15), color: Theme.secondaryText, alignment: .center)
    private lazy var permissionButton = Theme.primaryButton("Turn on notifications")
    private lazy var openSettingsButton = Theme.quietButton("Open Settings", color: Theme.accent)

    private var startPicker = UIDatePicker()
    private var endPicker = UIDatePicker()

    private var pageCount: Int { 4 }
    private var currentPage = 0 {
        didSet { updateChrome() }
    }

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
        // Re-entering from Settings keeps whatever the user already has.
        settings = AppCore.shared.settings
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Black on purpose: a light-mode device must not get grey system chrome.
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = Theme.background
        buildLayout()
        updateChrome()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await refreshPermissionState() }
    }

    // MARK: - Layout

    private func buildLayout() {
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        pageControl.numberOfPages = pageCount
        pageControl.currentPageIndicatorTintColor = Theme.accent
        pageControl.pageIndicatorTintColor = UIColor(white: 1, alpha: 0.18)
        pageControl.isUserInteractionEnabled = false
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControl)

        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(finish), for: .touchUpInside)
        // Both buttons live in one stack: whichever is hidden collapses, so no
        // page carries an empty 56pt band under the page dots.
        bottomStack = Controls.stack([nextButton, skipButton], spacing: 4)
        view.addSubview(bottomStack)

        let pages = Controls.stack([page1(), page2(), page3(), page4()], axis: .horizontal, spacing: 0)
        pages.distribution = .fillEqually
        scrollView.addSubview(pages)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -8),

            pages.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            pages.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            pages.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            pages.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            pages.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            pages.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, multiplier: 4),

            pageControl.bottomAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -16),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            bottomStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.sidePadding),
            bottomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.sidePadding),
            bottomStack.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12)
        ])
    }

    private func pageShell(title: String, body: String, extra: UIView?) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = Theme.label(title, font: Theme.title(40), alignment: .center)
        let bodyLabel = Theme.label(body, font: Theme.body(18), color: Theme.secondaryText, alignment: .center)

        var views: [UIView] = [titleLabel, bodyLabel]
        if let extra {
            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.heightAnchor.constraint(equalToConstant: 12).isActive = true
            views.append(spacer)
            views.append(extra)
        }
        let stack = Controls.stack(views, spacing: 16)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        container.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            stack.topAnchor.constraint(greaterThanOrEqualTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: Theme.sidePadding),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -Theme.sidePadding),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -Theme.sidePadding * 2),
            // Every page starts its title at the same height. Centring each page
            // on its own content made the headline jump about while swiping.
            stack.topAnchor.constraint(equalTo: scroll.frameLayoutGuide.topAnchor, constant: 96)
                .withPriority(.defaultHigh)
        ])
        return container
    }

    // MARK: - Pages

    private func page1() -> UIView {
        pageShell(
            title: "Tiny sets.\nAll day.",
            body: "Micro Gains pings you a few times a day with one quick set. Ten push-ups. A minute plank. That's it.",
            extra: nil
        )
    }

    private func page2() -> UIView {
        let interval = Controls.segmented(
            AppSettings.intervalOptions.map(Controls.intervalLabel),
            selected: AppSettings.intervalOptions.firstIndex(of: settings.intervalMinutes) ?? 2
        )
        interval.accessibilityLabel = "Reminder interval"
        interval.addTarget(self, action: #selector(intervalChanged(_:)), for: .valueChanged)

        startPicker = timePicker(minuteOfDay: settings.activeStartMinute, action: #selector(startChanged(_:)))
        startPicker.accessibilityLabel = "Active hours start"
        endPicker = timePicker(minuteOfDay: settings.activeEndMinute, action: #selector(endChanged(_:)))
        endPicker.accessibilityLabel = "Active hours end"

        let hours = Controls.stack([
            AdaptiveRowCard(title: "From", accessory: startPicker),
            AdaptiveRowCard(title: "Until", accessory: endPicker)
        ], spacing: 8)

        setsPerDayLabel.text = Controls.setsPerDayLine(settings)

        return pageShell(
            title: "How often?",
            body: "Pick the gap between pings and the hours you want them.",
            extra: Controls.stack([interval, hours, setsPerDayLabel], spacing: 20)
        )
    }

    private func page3() -> UIView {
        let difficulty = Controls.segmented(
            Difficulty.allCases.map(\.title),
            selected: Difficulty.allCases.firstIndex(of: settings.difficulty) ?? 1
        )
        difficulty.accessibilityLabel = "Difficulty"
        difficulty.addTarget(self, action: #selector(difficultyChanged(_:)), for: .valueChanged)
        difficultyExampleLabel.text = Controls.difficultyExample(settings.difficulty, catalog: AppCore.shared.catalog.snapshot())

        let toggle = Controls.toggle(on: settings.officeMode)
        toggle.accessibilityLabel = "Office mode"
        toggle.addTarget(self, action: #selector(officeChanged(_:)), for: .valueChanged)

        let office = AdaptiveRowCard(
            title: "I'm mostly at a desk",
            subtitle: "Only sets you can do at a desk",
            accessory: toggle
        )

        return pageShell(
            title: "How hard?",
            body: "Change this any time. Any single exercise can drop a level later.",
            extra: Controls.stack([difficulty, difficultyExampleLabel, office], spacing: 16)
        )
    }

    private func page4() -> UIView {
        permissionButton.addTarget(self, action: #selector(requestPermission), for: .touchUpInside)
        openSettingsButton.addTarget(self, action: #selector(openSystemSettings), for: .touchUpInside)
        openSettingsButton.isHidden = true
        openSettingsButton.accessibilityLabel = "Open iOS Settings"
        permissionNoteLabel.text = Controls.setsPerDayLine(settings) + " with your current settings."

        return pageShell(
            title: "Let us\nping you.",
            body: "A ping is the whole product, so Micro Gains needs permission to send them.",
            extra: Controls.stack([permissionButton, permissionNoteLabel, openSettingsButton], spacing: 14)
        )
    }

    // MARK: - Small builders

    private func timePicker(minuteOfDay: Int, action: Selector) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .compact
        picker.minuteInterval = 15
        picker.tintColor = Theme.accent
        picker.overrideUserInterfaceStyle = .dark
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.date = Controls.pickerDate(minuteOfDay: minuteOfDay)
        picker.addTarget(self, action: action, for: .valueChanged)
        return picker
    }

    // MARK: - Actions

    @objc private func intervalChanged(_ sender: UISegmentedControl) {
        settings.intervalMinutes = AppSettings.intervalOptions[sender.selectedSegmentIndex]
        repairWindow(edited: .interval)
        refreshLiveLines()
    }

    @objc private func difficultyChanged(_ sender: UISegmentedControl) {
        settings.difficulty = Difficulty.allCases[sender.selectedSegmentIndex]
        refreshLiveLines()
    }

    @objc private func officeChanged(_ sender: UISwitch) {
        settings.officeMode = sender.isOn
    }

    @objc private func startChanged(_ sender: UIDatePicker) {
        settings.activeStartMinute = minuteOfDay(sender.date)
        repairWindow(edited: .start)
        refreshLiveLines()
    }

    @objc private func endChanged(_ sender: UIDatePicker) {
        settings.activeEndMinute = minuteOfDay(sender.date)
        repairWindow(edited: .end)
        refreshLiveLines()
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// The window has to end more than one interval after it starts, or the
    /// Worker rejects the settings with a 400. Nudge whichever value the user
    /// did not just touch, and show the repaired time straight away.
    private func repairWindow(edited: Controls.WindowEdit) {
        let fixed = Controls.repairedWindow(
            start: settings.activeStartMinute,
            end: settings.activeEndMinute,
            interval: settings.intervalMinutes,
            edited: edited
        )
        guard fixed.start != settings.activeStartMinute || fixed.end != settings.activeEndMinute else { return }
        settings.activeStartMinute = fixed.start
        settings.activeEndMinute = fixed.end
        startPicker.date = Controls.pickerDate(minuteOfDay: fixed.start)
        endPicker.date = Controls.pickerDate(minuteOfDay: fixed.end)
        UIAccessibility.post(
            notification: .announcement,
            argument: "Active hours are now \(Controls.minuteLabel(fixed.start)) to \(Controls.minuteLabel(fixed.end))"
        )
    }

    private func refreshLiveLines() {
        setsPerDayLabel.text = Controls.setsPerDayLine(settings)
        permissionNoteLabel.text = Controls.setsPerDayLine(settings) + " with your current settings."
        difficultyExampleLabel.text = Controls.difficultyExample(
            settings.difficulty,
            catalog: AppCore.shared.catalog.snapshot()
        )
    }

    @objc private func nextTapped() {
        advance()
    }

    /// Moves to the next page, or finishes on the last one. Exposed so the
    /// paging and the hand-off to Home can be tested without a tap.
    func advance() {
        guard currentPage < pageCount - 1 else {
            finish()
            return
        }
        let target = currentPage + 1
        scrollView.setContentOffset(
            CGPoint(x: CGFloat(target) * scrollView.bounds.width, y: 0),
            animated: !Theme.reduceMotion
        )
        currentPage = target
    }

    var visiblePageIndex: Int { currentPage }
    var pendingSettings: AppSettings { settings }

    @objc private func requestPermission() {
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            AppCore.shared.settingsStore.permissionExplainerShown = true
            if granted {
                finish()
            } else {
                await refreshPermissionState()
            }
        }
    }

    @objc private func openSystemSettings() {
        Task { @MainActor in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            await UIApplication.shared.open(url)
        }
    }

    /// Denial is not a dead end: keep the direct link to iOS Settings on screen
    /// and let the user carry on regardless.
    private func refreshPermissionState() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard status == .denied else {
            openSettingsButton.isHidden = true
            return
        }
        permissionNoteLabel.text = "Notifications are off. Turn them on in iOS Settings when you want them."
        permissionButton.isHidden = true
        openSettingsButton.isHidden = false
    }

    @objc func finish() {
        settings.timezone = TimeZone.current.identifier
        AppCore.shared.settings = settings
        AppCore.shared.settingsStore.onboardingCompleted = true
        Task {
            await SyncCoordinator.shared.pushSettings(settings)
            await AppCore.shared.reschedule()
        }
        onFinish()
    }

    private func updateChrome() {
        pageControl.currentPage = currentPage
        // The last page already has its own primary button, so the bottom bar
        // steps aside and leaves only the quiet way through.
        let isLast = currentPage == pageCount - 1
        nextButton.isHidden = isLast
        nextButton.accessibilityLabel = "Continue to the next page"
        skipButton.isHidden = !isLast
        skipButton.configuration?.title = "Skip for now"
        skipButton.accessibilityLabel = "Continue without reminders"
        skipButton.setNeedsUpdateConfiguration()
    }
}

extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > 0 else { return }
        currentPage = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
    }
}

extension NSLayoutConstraint {
    /// Lets a centring constraint yield when the content is taller than the page.
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
