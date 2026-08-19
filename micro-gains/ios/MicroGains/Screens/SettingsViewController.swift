import UIKit
import UserNotifications

/// Grouped list. Every row writes settings straight through, which pushes them
/// to the server and re-runs the scheduler.
final class SettingsViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case schedule, difficulty, days, filters, pause, permission, data

        var header: String? {
            switch self {
            case .schedule: return "Reminders"
            case .difficulty: return "Difficulty"
            case .days: return "Days"
            case .filters: return "What you get"
            case .pause: return nil
            case .permission: return nil
            case .data: return nil
            }
        }
    }

    private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private let shortDayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    /// Held so a repaired window can be shown in place, without a reloadData
    /// that would close the picker the user is standing in.
    private weak var startPicker: UIDatePicker?
    private weak var endPicker: UIDatePicker?

    init() {
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        // Black on purpose: a light-mode device must not get grey system chrome.
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = Theme.background
        tableView.backgroundColor = Theme.background
        tableView.separatorColor = Theme.separator
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.estimatedSectionFooterHeight = 30
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { @MainActor in
            authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            await AppCore.shared.refreshPendingCount()
            tableView.reloadData()
        }
    }

    private var settings: AppSettings { AppCore.shared.settings }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .schedule: return 3      // interval, start, end
        case .difficulty: return 1
        case .days: return 1
        case .filters: return 2
        case .pause: return 2
        case .permission: return 1
        case .data: return 2
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.header
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .schedule:
            return Controls.setsPerDayLine(settings)
        case .difficulty:
            return Controls.difficultyExample(settings.difficulty, catalog: AppCore.shared.catalog.snapshot())
        case .permission:
            let count = AppCore.shared.pendingNotificationCount
            return count == 1 ? "1 reminder scheduled" : "\(count) reminders scheduled"
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Theme.secondaryText
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Theme.secondaryText
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.contentView.subviews.filter { $0.tag == 99 }.forEach { $0.removeFromSuperview() }
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.selectionStyle = .default
        cell.backgroundColor = Theme.surface

        var content = cell.defaultContentConfiguration()
        content.textProperties.color = Theme.text
        content.secondaryTextProperties.color = Theme.secondaryText
        content.textProperties.font = Theme.body(17)
        // Without this the stock caption font outgrows the row title at the
        // accessibility sizes, so the explanation shouts over its own label.
        content.secondaryTextProperties.font = Theme.body(14)

        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            switch indexPath.row {
            case 0:
                let control = Controls.segmented(
                    AppSettings.intervalOptions.map(Controls.intervalLabel),
                    selected: AppSettings.intervalOptions.firstIndex(of: settings.intervalMinutes) ?? 2
                )
                control.addTarget(self, action: #selector(intervalChanged(_:)), for: .valueChanged)
                control.accessibilityLabel = "Reminder interval"
                embedBelow(control, in: cell, title: "Remind me every")
                return cell
            case 1:
                let picker = timePicker(minuteOfDay: settings.activeStartMinute, action: #selector(startChanged(_:)), label: "Active hours start")
                startPicker = picker
                embedRow("Active from", accessory: picker, in: cell)
                cell.selectionStyle = .none
                return cell
            default:
                let picker = timePicker(minuteOfDay: settings.activeEndMinute, action: #selector(endChanged(_:)), label: "Active hours end")
                endPicker = picker
                embedRow("Until", accessory: picker, in: cell)
                cell.selectionStyle = .none
                return cell
            }

        case .difficulty:
            let control = Controls.segmented(
                Difficulty.allCases.map(\.title),
                selected: Difficulty.allCases.firstIndex(of: settings.difficulty) ?? 1
            )
            control.addTarget(self, action: #selector(difficultyChanged(_:)), for: .valueChanged)
            control.accessibilityLabel = "Difficulty"
            embedBelow(control, in: cell, title: nil)
            cell.selectionStyle = .none
            return cell

        case .days:
            let control = DayToggleRow(names: shortDayNames, mask: settings.activeDays) { [weak self] mask in
                AppCore.shared.update { $0.activeDays = mask }
                self?.reloadFooters()
            }
            control.fullNames = dayNames
            // Seven buttons across a phone only clear the 44pt tap target if the
            // row gives up most of its horizontal padding.
            embedBelow(control, in: cell, title: nil, horizontalInset: 8)
            cell.selectionStyle = .none
            return cell

        case .filters:
            if indexPath.row == 0 {
                content.text = "Office mode"
                content.secondaryText = "Only sets you can do at a desk"
                cell.contentConfiguration = content
                let toggle = Controls.toggle(on: settings.officeMode)
                toggle.accessibilityLabel = "Office mode"
                toggle.addTarget(self, action: #selector(officeChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggle
            } else {
                content.text = "Floor exercises"
                content.secondaryText = "Planks, bridges and anything on the floor"
                cell.contentConfiguration = content
                let toggle = Controls.toggle(on: settings.floorOk)
                toggle.accessibilityLabel = "Floor exercises"
                toggle.addTarget(self, action: #selector(floorChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggle
            }
            cell.selectionStyle = .none
            return cell

        case .pause:
            if indexPath.row == 0 {
                content.text = "Pause until tomorrow"
                content.textProperties.color = settings.enabled ? Theme.accent : Theme.secondaryText
                cell.contentConfiguration = content
            } else {
                content.text = "Pause"
                content.secondaryText = settings.enabled ? nil : "No reminders while this is on"
                cell.contentConfiguration = content
                let toggle = Controls.toggle(on: !settings.enabled)
                toggle.accessibilityLabel = "Pause all reminders"
                toggle.addTarget(self, action: #selector(pauseChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggle
                cell.selectionStyle = .none
            }
            return cell

        case .permission:
            content.text = "Notifications"
            switch authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                content.secondaryText = "On"
                cell.selectionStyle = .none
            case .denied:
                content.secondaryText = "Off. Open iOS Settings to turn them on."
                cell.accessoryType = .disclosureIndicator
            default:
                content.secondaryText = "Not asked yet"
                cell.accessoryType = .disclosureIndicator
            }
            cell.contentConfiguration = content
            return cell

        case .data:
            if indexPath.row == 0 {
                content.text = "Show intro again"
                cell.contentConfiguration = content
                cell.accessoryType = .disclosureIndicator
            } else {
                content.text = "Erase my data"
                content.textProperties.color = Theme.destructive
                cell.contentConfiguration = content
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .pause where indexPath.row == 0:
            pauseUntilTomorrow()
        case .permission:
            openNotificationSettings()
        case .data where indexPath.row == 0:
            showIntroAgain()
        case .data:
            confirmErase()
        default:
            break
        }
    }

    // MARK: - Row plumbing

    /// Puts a wide control under an optional row title so segmented controls get
    /// the full width instead of being squeezed into an accessory slot. This
    /// builds the label by hand: assigning a content configuration would replace
    /// the content view and orphan these constraints.
    private func embedBelow(_ control: UIView, in cell: UITableViewCell, title: String?, horizontalInset: CGFloat = 16) {
        cell.contentConfiguration = nil
        control.tag = 99
        control.translatesAutoresizingMaskIntoConstraints = false

        let stack = Controls.stack([], spacing: 10)
        stack.tag = 99
        if let title {
            stack.addArrangedSubview(Theme.label(title, font: Theme.body(17), color: Theme.text))
        }
        stack.addArrangedSubview(control)
        cell.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: horizontalInset),
            stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -horizontalInset),
            stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
        ])
    }

    /// A row title beside one control. As an `accessoryView` the date picker
    /// grew until the title had no width left and vanished, so the pair lives in
    /// a stack that turns vertical at the accessibility sizes instead.
    private func embedRow(_ title: String, accessory: UIView, in cell: UITableViewCell) {
        cell.contentConfiguration = nil
        let label = Theme.label(title, font: Theme.body(17), color: Theme.text)
        accessory.setContentHuggingPriority(.required, for: .horizontal)
        accessory.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stacked = Controls.isAccessibilitySize(traitCollection)
        let stack = Controls.stack(
            [label, accessory],
            axis: stacked ? .vertical : .horizontal,
            spacing: stacked ? 10 : 12,
            alignment: stacked ? .leading : .center
        )
        stack.tag = 99
        cell.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            stack.heightAnchor.constraint(greaterThanOrEqualToConstant: Theme.minimumTapTarget)
        ])
    }

    private func timePicker(minuteOfDay: Int, action: Selector, label: String) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .compact
        picker.minuteInterval = 15
        picker.tintColor = Theme.accent
        picker.overrideUserInterfaceStyle = .dark
        picker.accessibilityLabel = label
        picker.date = Controls.pickerDate(minuteOfDay: minuteOfDay)
        picker.addTarget(self, action: action, for: .valueChanged)
        picker.sizeToFit()
        return picker
    }

    private func reloadFooters() {
        UIView.performWithoutAnimation {
            tableView.reloadSections(
                IndexSet([Section.schedule.rawValue, Section.difficulty.rawValue, Section.permission.rawValue]),
                with: .none
            )
        }
    }

    // MARK: - Actions

    @objc private func intervalChanged(_ sender: UISegmentedControl) {
        let value = AppSettings.intervalOptions[sender.selectedSegmentIndex]
        AppCore.shared.update { settings in
            settings.intervalMinutes = value
            applyRepairedWindow(to: &settings, edited: .interval)
        }
        showRepairedWindow()
        reloadFooters()
    }

    @objc private func difficultyChanged(_ sender: UISegmentedControl) {
        let value = Difficulty.allCases[sender.selectedSegmentIndex]
        AppCore.shared.update { $0.difficulty = value }
        reloadFooters()
    }

    @objc private func officeChanged(_ sender: UISwitch) {
        AppCore.shared.update { $0.officeMode = sender.isOn }
    }

    @objc private func floorChanged(_ sender: UISwitch) {
        AppCore.shared.update { $0.floorOk = sender.isOn }
    }

    @objc private func pauseChanged(_ sender: UISwitch) {
        AppCore.shared.update { $0.enabled = !sender.isOn }
        tableView.reloadData()
    }

    @objc private func startChanged(_ sender: UIDatePicker) {
        let minute = minuteOfDay(sender.date)
        AppCore.shared.update { settings in
            settings.activeStartMinute = minute
            applyRepairedWindow(to: &settings, edited: .start)
        }
        showRepairedWindow()
        reloadFooters()
    }

    @objc private func endChanged(_ sender: UIDatePicker) {
        let minute = minuteOfDay(sender.date)
        AppCore.shared.update { settings in
            settings.activeEndMinute = minute
            applyRepairedWindow(to: &settings, edited: .end)
        }
        showRepairedWindow()
        reloadFooters()
    }

    /// The Worker rejects any window where `end <= start + interval` with a 400,
    /// so an impossible pair never leaves this screen. Whichever value the user
    /// did not just touch is the one that moves.
    private func applyRepairedWindow(to settings: inout AppSettings, edited: Controls.WindowEdit) {
        let fixed = Controls.repairedWindow(
            start: settings.activeStartMinute,
            end: settings.activeEndMinute,
            interval: settings.intervalMinutes,
            edited: edited
        )
        settings.activeStartMinute = fixed.start
        settings.activeEndMinute = fixed.end
    }

    /// Puts the repaired times back into the pickers straight away, so the user
    /// sees what was actually saved.
    private func showRepairedWindow() {
        let settings = self.settings
        let start = Controls.pickerDate(minuteOfDay: settings.activeStartMinute)
        let end = Controls.pickerDate(minuteOfDay: settings.activeEndMinute)
        var moved = false
        if let startPicker, startPicker.date != start {
            startPicker.date = start
            moved = true
        }
        if let endPicker, endPicker.date != end {
            endPicker.date = end
            moved = true
        }
        guard moved else { return }
        UIAccessibility.post(
            notification: .announcement,
            argument: "Active hours are now \(Controls.minuteLabel(settings.activeStartMinute)) to \(Controls.minuteLabel(settings.activeEndMinute))"
        )
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// Sets paused_until to the next active-window start. The pipeline stays,
    /// the slots before that point are skipped.
    private func pauseUntilTomorrow() {
        let settings = self.settings
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        let today = calendar.startOfDay(for: Date())

        for offset in 1...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { break }
            let weekdayIndex = (calendar.component(.weekday, from: day) + 5) % 7
            guard settings.isActive(weekdayIndex: weekdayIndex) else { continue }
            guard let start = Scheduler.wallClock(
                day: day,
                minuteOfDay: settings.activeStartMinute,
                calendar: calendar
            ) else { continue }
            AppCore.shared.update { $0.pausedUntil = start }
            break
        }
        tableView.reloadData()
    }

    private func openNotificationSettings() {
        Task { @MainActor in
            if authorizationStatus == .notDetermined {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                await AppCore.shared.reschedule()
                tableView.reloadData()
                return
            }
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            await UIApplication.shared.open(url)
        }
    }

    private func showIntroAgain() {
        guard let scene = view.window?.windowScene?.delegate as? SceneDelegate else { return }
        scene.showOnboarding()
    }

    private func confirmErase() {
        let alert = UIAlertController(
            title: "Erase my data",
            message: "Deletes every set and your settings, here and on the server. There is no undo.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Erase", style: .destructive) { [weak self] _ in
            self?.erase()
        })
        present(alert, animated: !Theme.reduceMotion)
    }

    private func erase() {
        Task { @MainActor in
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            await SyncCoordinator.shared.eraseEverything()
            await AppCore.shared.refreshPendingCount()
            guard let scene = view.window?.windowScene?.delegate as? SceneDelegate else { return }
            scene.showOnboarding()
        }
    }
}

/// Seven day toggles in one row. A stack of buttons rather than seven table
/// rows, so the whole week fits in one glance.
final class DayToggleRow: UIView {
    var fullNames: [String] = []
    private let names: [String]
    private var dayMask: Int
    private let onChange: (Int) -> Void
    private var buttons: [UIButton] = []

    init(names: [String], mask: Int, onChange: @escaping (Int) -> Void) {
        self.names = names
        self.dayMask = mask
        self.onChange = onChange
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stack = Controls.stack([], axis: .horizontal, spacing: 4)
        stack.distribution = .fillEqually
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(equalToConstant: Theme.minimumTapTarget)
        ])

        for (index, name) in names.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(name, for: .normal)
            button.titleLabel?.font = Controls.segmentFont(13, weight: .semibold)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.layer.cornerRadius = 10
            button.layer.cornerCurve = .continuous
            button.tag = index
            button.addTarget(self, action: #selector(toggle(_:)), for: .touchUpInside)
            buttons.append(button)
            stack.addArrangedSubview(button)
        }
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    @objc private func toggle(_ sender: UIButton) {
        dayMask ^= (1 << sender.tag)
        // At least one day has to stay on, otherwise nothing ever fires.
        if dayMask == 0 { dayMask = 1 << sender.tag }
        refresh()
        onChange(dayMask)
    }

    private func refresh() {
        for (index, button) in buttons.enumerated() {
            let on = (dayMask >> index) & 1 == 1
            button.backgroundColor = on ? Theme.green : UIColor(white: 1, alpha: 0.06)
            button.setTitleColor(on ? .white : Theme.secondaryText, for: .normal)
            let name = index < fullNames.count ? fullNames[index] : names[index]
            button.accessibilityLabel = name
            button.accessibilityValue = on ? "On" : "Off"
            button.accessibilityTraits = on ? [.button, .selected] : .button
        }
    }
}
