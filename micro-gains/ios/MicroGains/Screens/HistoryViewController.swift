import UIKit

/// Thirty days of bars plus the totals. Local data first; the server copy
/// replaces it if it arrives.
final class HistoryViewController: UIViewController {
    private let chart = BarStripView()
    private let rangeLabel = Theme.label(font: Theme.body(13), color: Theme.secondaryText)
    private let totalsStack = Controls.stack([], spacing: 10)
    private let emptyLabel = Theme.label(
        "No sets yet. Your first one lands here.",
        font: Theme.body(16),
        color: Theme.secondaryText,
        alignment: .center
    )
    private let scrollView = UIScrollView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "History"
        // Black on purpose: a light-mode device must not get grey system chrome.
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = Theme.background
        buildLayout()
        reload()
    }

    private func buildLayout() {
        let card = Theme.card()
        card.addSubview(chart)
        card.addSubview(rangeLabel)
        NSLayoutConstraint.activate([
            chart.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            chart.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            chart.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chart.heightAnchor.constraint(equalToConstant: 92),
            rangeLabel.topAnchor.constraint(equalTo: chart.bottomAnchor, constant: 10),
            rangeLabel.leadingAnchor.constraint(equalTo: chart.leadingAnchor),
            rangeLabel.trailingAnchor.constraint(equalTo: chart.trailingAnchor),
            rangeLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        emptyLabel.isHidden = true
        let stack = Controls.stack([card, emptyLabel, totalsStack], spacing: 24)

        // Five totals at an accessibility type size are taller than the phone.
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.sidePadding),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.sidePadding),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -Theme.sidePadding * 2)
        ])
    }

    private func reload() {
        Task { @MainActor in
            let settings = AppCore.shared.settings
            let now = Date()
            let days = await AppCore.shared.store.history(days: 30, now: now, timeZone: settings.timeZone)
            let stats = await AppCore.shared.store.stats(now: now, settings: settings)
            render(days: days, stats: stats)

            // The server has the full picture across reinstalls, but only once
            // the outbox has landed: asking first showed a total that was behind
            // the one already on screen, and today's bar vanished.
            await SyncCoordinator.shared.flushOutbox()
            if let remote = await SyncCoordinator.shared.serverHistory(days: 30),
               remote.stats.totalDone >= stats.totalDone {
                render(days: remote.days, stats: remote.stats)
            }
        }
    }

    private func render(days: [HistoryDay], stats: Stats) {
        chart.days = days
        let isEmpty = stats.totalDone == 0 && stats.totalSeconds == 0
        emptyLabel.isHidden = !isEmpty
        // Five rows of zeros say nothing the one line above them does not.
        totalsStack.isHidden = isEmpty
        if let first = days.first?.date, let last = days.last?.date {
            rangeLabel.text = "\(short(first)) to \(short(last))"
            rangeLabel.accessibilityLabel = "\(short(first)) to \(short(last))"
        }

        totalsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let rows: [(String, String)] = [
            ("Sets done", "\(stats.totalDone)"),
            ("Reps", "\(stats.totalReps)"),
            ("Time held", formatSeconds(stats.totalSeconds)),
            ("Current streak", stats.streakDays == 1 ? "1 day" : "\(stats.streakDays) days"),
            ("Best streak", stats.bestStreakDays == 1 ? "1 day" : "\(stats.bestStreakDays) days")
        ]
        for (title, value) in rows {
            totalsStack.addArrangedSubview(totalRow(title, value))
        }
    }

    private func totalRow(_ title: String, _ value: String) -> UIView {
        TotalRow(title: title, value: value)
    }

    private func short(_ isoDay: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: isoDay) else { return isoDay }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    private func formatSeconds(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }
}

/// Thirty thin bars, one per day, drawn by hand. Height is sets done that day.
final class BarStripView: UIView {
    var days: [HistoryDay] = [] {
        didSet {
            setNeedsDisplay()
            accessibilityLabel = "\(days.reduce(0) { $0 + $1.done }) sets over \(days.count) days"
        }
    }

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

    override func draw(_ rect: CGRect) {
        guard !days.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }
        let peak = max(days.map(\.done).max() ?? 1, 1)
        let spacing: CGFloat = 3
        let width = max((rect.width - spacing * CGFloat(days.count - 1)) / CGFloat(days.count), 2)
        let baseline = rect.maxY - 1

        // A hairline floor so an empty stretch still reads as days, not nothing.
        context.setFillColor(UIColor(white: 1, alpha: 0.08).cgColor)
        context.fill(CGRect(x: 0, y: baseline, width: rect.width, height: 1))

        for (index, day) in days.enumerated() {
            let x = CGFloat(index) * (width + spacing)
            let fraction = CGFloat(day.done) / CGFloat(peak)
            let height = day.done > 0 ? max(fraction * (rect.height - 6), 4) : 3
            let bar = CGRect(x: x, y: baseline - height, width: width, height: height)
            let color: UIColor = day.done > 0
                ? Theme.accent.withAlphaComponent(0.55 + 0.45 * fraction)
                : UIColor(white: 1, alpha: 0.12)
            context.setFillColor(color.cgColor)
            let path = UIBezierPath(roundedRect: bar, cornerRadius: min(width / 2, 3))
            context.addPath(path.cgPath)
            context.fillPath()
        }
    }
}

/// Label on the left, number on the right, until an accessibility type size
/// makes that a fight neither side wins. Then the number moves underneath.
final class TotalRow: UIView {
    private let stack: UIStackView
    private let valueLabel: UILabel

    init(title: String, value: String) {
        let titleLabel = Theme.label(title, font: Theme.body(16), color: Theme.secondaryText)
        valueLabel = Theme.label(value, font: Theme.numerals(18), color: Theme.text)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        stack = Controls.stack([titleLabel, valueLabel], axis: .horizontal, spacing: 12, alignment: .firstBaseline)

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .staticText
        accessibilityLabel = "\(title), \(value)"

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
        stack.alignment = stacked ? .leading : .firstBaseline
        valueLabel.textAlignment = stacked ? .natural : .right
    }
}

