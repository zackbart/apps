import UIKit

/// Small shared pieces. Nothing here knows about a specific screen.
enum Controls {
    /// A segmented control that reads as part of the dark theme rather than as
    /// a stock iOS control dropped on top of it.
    static func segmented(_ titles: [String], selected: Int) -> UISegmentedControl {
        let control = UISegmentedControl(items: titles)
        control.selectedSegmentIndex = selected
        control.translatesAutoresizingMaskIntoConstraints = false
        control.backgroundColor = Theme.surface
        control.selectedSegmentTintColor = Theme.green
        control.setTitleTextAttributes([
            .foregroundColor: Theme.secondaryText,
            .font: segmentFont(weight: .medium)
        ], for: .normal)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: segmentFont(weight: .semibold)
        ], for: .selected)
        control.heightAnchor.constraint(greaterThanOrEqualToConstant: Theme.minimumTapTarget).isActive = true
        return control
    }

    /// Segment titles scale with Dynamic Type but stop well short of the body
    /// cap: five segments across a phone have nowhere to grow, and a truncated
    /// "1.5 h" is worse than a slightly small one.
    static func segmentFont(_ size: CGFloat = 15, weight: UIFont.Weight = .medium) -> UIFont {
        UIFontMetrics(forTextStyle: .footnote).scaledFont(
            for: UIFont.systemFont(ofSize: size, weight: weight),
            maximumPointSize: size * 1.25
        )
    }

    /// True at the accessibility Dynamic Type sizes, where side-by-side rows
    /// have to become stacked ones.
    static func isAccessibilitySize(_ traits: UITraitCollection) -> Bool {
        traits.preferredContentSizeCategory.isAccessibilityCategory
    }

    /// Left on frame-based layout on purpose: a table cell positions an
    /// `accessoryView` by its frame, and turning that off dropped the Pause
    /// switch on top of its own label. A stack view flips the flag itself when
    /// the switch is used as an arranged subview instead.
    static func toggle(on: Bool) -> UISwitch {
        let control = UISwitch()
        control.isOn = on
        control.onTintColor = Theme.green
        control.sizeToFit()
        return control
    }

    static func stack(
        _ views: [UIView],
        axis: NSLayoutConstraint.Axis = .vertical,
        spacing: CGFloat = 12,
        alignment: UIStackView.Alignment = .fill
    ) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = axis
        stack.spacing = spacing
        stack.alignment = alignment
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    /// "About 6 sets a day". Rule 8.
    static func setsPerDayLine(_ settings: AppSettings) -> String {
        let count = settings.setsPerDay
        guard count > 0 else { return "No sets scheduled" }
        return count == 1 ? "About 1 set a day" : "About \(count) sets a day"
    }

    /// "Medium: 10 push-ups, 15 squats, 45 s plank", built from the live catalog
    /// so it never drifts from what the app actually prescribes.
    static func difficultyExample(_ difficulty: Difficulty, catalog: [Exercise]) -> String {
        func target(_ id: String, fallback: Int) -> Int {
            catalog.first { $0.id == id }?.target(at: difficulty) ?? fallback
        }
        let pushUps = target("full_pushup", fallback: 10)
        let squats = target("air_squat", fallback: 18)
        let plank = target("forearm_plank", fallback: 40)
        return "\(pushUps) push-ups, \(squats) squats, \(plank) s plank"
    }

    /// Which control the user just touched. The repair moves the *other* value
    /// wherever it can, so an edit is never silently thrown away.
    enum WindowEdit {
        case start, end, interval
    }

    /// Keeps the active window inside the server's rule (`end > start + interval`,
    /// server/src/validation.ts) and on the 15 minute grid the pickers use, so
    /// the value handed back is one a picker can actually display.
    static func repairedWindow(
        start: Int,
        end: Int,
        interval: Int,
        edited: WindowEdit,
        step: Int = 15
    ) -> (start: Int, end: Int) {
        if AppSettings.isValidWindow(start: start, end: end, interval: interval) {
            return (start, end)
        }

        if edited == .end {
            // The user just named an end time. Walk the start back to make room
            // rather than overriding the time they picked.
            let movedStart = max(0, floorToStep(end - interval - step, step))
            if AppSettings.isValidWindow(start: movedStart, end: end, interval: interval) {
                return (movedStart, end)
            }
            // Not even midnight is early enough, so give the day its shortest
            // legal window instead of pushing the end past what they asked for.
            let earliest = min(ceilToStep(interval + step, step), 1440)
            if AppSettings.isValidWindow(start: 0, end: earliest, interval: interval) {
                return (0, earliest)
            }
        }

        let fixed = AppSettings.repairedWindow(start: start, end: end, interval: interval)
        let snapped = (start: floorToStep(fixed.start, step), end: min(ceilToStep(fixed.end, step), 1440))
        if AppSettings.isValidWindow(start: snapped.start, end: snapped.end, interval: interval) {
            return snapped
        }
        // A late start with a long interval runs off the end of the day: pull the
        // start back onto the grid instead.
        let pulledStart = max(0, floorToStep(snapped.end - interval - step, step))
        if AppSettings.isValidWindow(start: pulledStart, end: snapped.end, interval: interval) {
            return (pulledStart, snapped.end)
        }
        return fixed
    }

    private static func floorToStep(_ value: Int, _ step: Int) -> Int {
        Int((Double(value) / Double(step)).rounded(.down)) * step
    }

    private static func ceilToStep(_ value: Int, _ step: Int) -> Int {
        Int((Double(value) / Double(step)).rounded(.up)) * step
    }

    /// A `.time` picker date for a minute-of-day. 1440 lands on midnight of the
    /// next day, which reads as 12:00 AM.
    static func pickerDate(minuteOfDay: Int) -> Date {
        var components = DateComponents()
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }

    static func minuteLabel(_ minuteOfDay: Int) -> String {
        var components = DateComponents()
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    static func intervalLabel(_ minutes: Int) -> String {
        switch minutes {
        case 60: return "1 h"
        case 90: return "1.5 h"
        case 120: return "2 h"
        case 180: return "3 h"
        case 240: return "4 h"
        default: return "\(minutes) m"
        }
    }
}

/// A card with a title (and optional second line) on one side and one control on
/// the other. At accessibility type sizes the two stop fighting over the width
/// and stack instead.
final class AdaptiveRowCard: UIView {
    private let stack: UIStackView

    init(title: String, subtitle: String? = nil, accessory: UIView) {
        let titleLabel = Theme.label(title, font: Theme.body(17, weight: subtitle == nil ? .regular : .medium))
        var textViews: [UIView] = [titleLabel]
        if let subtitle {
            textViews.append(Theme.label(subtitle, font: Theme.body(14), color: Theme.secondaryText))
        }
        let text = Controls.stack(textViews, spacing: 4)
        accessory.setContentHuggingPriority(.required, for: .horizontal)
        accessory.setContentCompressionResistancePriority(.required, for: .horizontal)
        stack = Controls.stack([text, accessory], axis: .horizontal, spacing: 12, alignment: .center)
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Theme.surface
        layer.cornerRadius = Theme.cornerRadius
        layer.cornerCurve = .continuous
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Theme.minimumTapTarget + 12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])

        applyAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.applyAxis()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    private func applyAxis() {
        let stacked = Controls.isAccessibilitySize(traitCollection)
        stack.axis = stacked ? .vertical : .horizontal
        stack.alignment = stacked ? .leading : .center
    }
}

