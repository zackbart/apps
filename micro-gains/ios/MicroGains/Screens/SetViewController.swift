import UIKit

/// The set itself. Huge numerals, one cue, Done and Skip. What a notification
/// tap opens and what "Do one now" pushes.
final class SetViewController: UIViewController {
    private let exercise: Exercise
    private let target: Int
    private let setID: String?

    private let nameLabel = Theme.label(font: Theme.title(28, weight: .semibold), color: Theme.secondaryText, alignment: .center)
    private let targetLabel = Theme.label(font: Theme.numerals(96), alignment: .center)
    private let unitLabel = Theme.label(font: Theme.title(24, weight: .medium), color: Theme.secondaryText, alignment: .center)
    private let cueLabel = Theme.label(font: Theme.body(16), color: Theme.secondaryText, alignment: .center)
    private let confirmationLabel = Theme.label(font: Theme.body(15, weight: .medium), color: Theme.accent, alignment: .center)

    private let doneButton = Theme.primaryButton("Done")
    private let skipButton = Theme.quietButton("Skip")
    private lazy var startButton = Theme.quietButton("Start", color: Theme.accent)
    private let ring = CountdownRingView()
    private let scrollView = UIScrollView()

    private var ringSize: NSLayoutConstraint?
    private var remaining: Int
    private var timer: Timer?
    private var isRunning = false
    private var isFinishing = false

    init(exercise: Exercise, target: Int, setID: String?) {
        self.exercise = exercise
        self.target = target
        self.setID = setID
        self.remaining = target
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    deinit { timer?.invalidate() }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        // The app is black on purpose, so a light-mode device must not get grey
        // system chrome inside this modal.
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = Theme.background
        buildLayout()
        if let setID {
            Task { await SetStore.shared.markDelivered(setID: setID) }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if DEBUG
        applyDebugCountdown()
        #endif
    }

    #if DEBUG
    /// `-mgTimer <seconds>` drops the countdown to that many seconds and starts
    /// it, so the ring mid-run and the finished state can be captured without a
    /// tap. Debug only, same shape as the other `-mg` QA arguments.
    private func applyDebugCountdown() {
        guard exercise.unit == .seconds, !isRunning else { return }
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-mgTimer"), index + 1 < arguments.count,
              let seconds = Int(arguments[index + 1]) else { return }
        remaining = max(min(seconds, target), 0)
        targetLabel.text = "\(remaining)"
        ring.progress = target > 0 ? 1 - Double(remaining) / Double(target) : 1
        toggleTimer()
    }
    #endif

    // MARK: - Layout

    private func buildLayout() {
        // SPEC: "15" with "air squats" under it. For a seconds exercise the name
        // cannot live under the numeral, so it moves to the header instead.
        nameLabel.text = exercise.name
        nameLabel.isHidden = exercise.unit == .reps
        targetLabel.text = "\(target)"
        targetLabel.numberOfLines = 1
        targetLabel.adjustsFontSizeToFitWidth = true
        targetLabel.minimumScaleFactor = 0.4
        unitLabel.text = exercise.unit == .reps
            ? Exercise.pluralPhrase(for: exercise.id, name: exercise.name)
            : "seconds"
        cueLabel.text = exercise.cue
        confirmationLabel.isHidden = true

        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        startButton.addTarget(self, action: #selector(toggleTimer), for: .touchUpInside)

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = Theme.secondaryText
        close.accessibilityLabel = "Close"
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)

        let numberStack = Controls.stack([targetLabel, unitLabel], spacing: 0, alignment: .center)
        ring.isHidden = exercise.unit != .seconds
        startButton.isHidden = exercise.unit != .seconds
        ring.addSubview(numberStack)

        let center = Controls.stack([nameLabel, ring, startButton, cueLabel, confirmationLabel], spacing: 18, alignment: .center)
        center.setCustomSpacing(26, after: nameLabel)

        // Accessibility type sizes push the numerals and the cue past the height
        // of the phone, so the middle of the screen scrolls.
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(center)

        view.addSubview(close)
        view.addSubview(scrollView)
        view.addSubview(doneButton)
        view.addSubview(skipButton)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            close.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.sidePadding),
            close.widthAnchor.constraint(equalToConstant: Theme.minimumTapTarget),
            close.heightAnchor.constraint(equalToConstant: Theme.minimumTapTarget),

            scrollView.topAnchor.constraint(equalTo: close.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -12),

            center.topAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            center.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            center.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Theme.sidePadding),
            center.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Theme.sidePadding),
            center.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -Theme.sidePadding * 2),
            center.centerYAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerYAnchor).withPriority(.defaultHigh),


            numberStack.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            numberStack.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            numberStack.widthAnchor.constraint(lessThanOrEqualTo: ring.widthAnchor, multiplier: 0.68),

            doneButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.sidePadding),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.sidePadding),
            doneButton.bottomAnchor.constraint(equalTo: skipButton.topAnchor, constant: -6),

            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12)
        ])

        let size = ring.widthAnchor.constraint(equalToConstant: 240)
        size.isActive = true
        ringSize = size
        ring.heightAnchor.constraint(equalTo: ring.widthAnchor).isActive = true

        // Reps get the same numeral in the same box, just without the ring
        // drawn around it.
        if exercise.unit == .reps {
            ring.isHidden = false
            ring.showsTrack = false
        }

        doneButton.accessibilityLabel = "Done, \(exercise.prescription(target: target))"
        skipButton.accessibilityLabel = "Skip this set"
        startButton.accessibilityLabel = "Start the countdown"
        nameLabel.accessibilityLabel = exercise.name
        targetLabel.accessibilityLabel = exercise.prescription(target: target)
        cueLabel.accessibilityLabel = exercise.cue
        unitLabel.isAccessibilityElement = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateRingSize()
    }

    /// The numerals grow with Dynamic Type, so the ring has to grow with them.
    /// Left at 240 the unit label ended up sitting on the stroke at the
    /// accessibility sizes.
    private func updateRingSize() {
        // Capped at 300: past that the ring pushes the cue off the bottom of a
        // phone even though the numerals have stopped needing the room.
        let scaled = min(UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: 240, compatibleWith: traitCollection), 300)
        let available = view.bounds.width - Theme.sidePadding * 2
        let size = (available > 240 ? min(max(scaled, 240), available) : 240).rounded()
        guard let ringSize, abs(ringSize.constant - size) > 0.5 else { return }
        ringSize.constant = size
    }

    // MARK: - Countdown

    @objc private func toggleTimer() {
        if isRunning {
            stopTimer()
            setStartTitle("Resume")
        } else {
            isRunning = true
            setStartTitle("Pause")
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    private func setStartTitle(_ title: String) {
        startButton.configuration?.title = title
        startButton.accessibilityLabel = title == "Pause" ? "Pause the countdown" : "\(title) the countdown"
        startButton.setNeedsUpdateConfiguration()
    }

    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard remaining > 0 else {
            stopTimer()
            return
        }
        remaining -= 1
        targetLabel.text = "\(remaining)"
        targetLabel.accessibilityLabel = "\(remaining) seconds left"
        ring.progress = target > 0 ? 1 - Double(remaining) / Double(target) : 1
        if remaining == 0 {
            stopTimer()
            startButton.isHidden = true
            unitLabel.text = "seconds"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement, argument: "Time is up")
        }
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        guard !isFinishing else { return }
        isFinishing = true
        stopTimer()
        Task { @MainActor in
            if let setID {
                let won = await AppCore.shared.log(setID: setID, status: .done, source: .app)
                guard won else {
                    await showAlreadyLoggedAndDismiss()
                    return
                }
            } else {
                _ = await SetStore.shared.logManual(
                    exercise: exercise,
                    target: target,
                    status: .done,
                    timeZone: AppCore.shared.settings.timeZone
                )
                NotificationCenter.default.post(name: .microGainsDataChanged, object: nil)
                Task { await SyncCoordinator.shared.flushOutbox() }
            }
            await showCheckAndDismiss()
        }
    }

    @objc private func skipTapped() {
        guard !isFinishing else { return }
        stopTimer()
        let sheet = UIAlertController(title: nil, message: "Skip this set?", preferredStyle: .actionSheet)
        for reason in SkipReason.allCases {
            sheet.addAction(UIAlertAction(title: reason.title, style: .default) { [weak self] _ in
                self?.skip(reason: reason)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = skipButton
        sheet.popoverPresentationController?.sourceRect = skipButton.bounds
        present(sheet, animated: !Theme.reduceMotion)
    }

    private func skip(reason: SkipReason) {
        guard !isFinishing else { return }
        isFinishing = true
        Task { @MainActor in
            if let setID {
                // The notification action may have answered this slot already.
                // Nothing was written, so nothing downstream may change either.
                let won = await AppCore.shared.log(setID: setID, status: .skipped, reason: reason, source: .app)
                guard won else {
                    await showAlreadyLoggedAndDismiss()
                    return
                }
            } else {
                _ = await SetStore.shared.logManual(
                    exercise: exercise,
                    target: target,
                    status: .skipped,
                    reason: reason,
                    timeZone: AppCore.shared.settings.timeZone
                )
                NotificationCenter.default.post(name: .microGainsDataChanged, object: nil)
            }

            // "Too hard" is the only reason that changes anything, and only once
            // the skip itself is on the books.
            if reason == .tooHard, let eased = AppCore.shared.lowerLevel(for: exercise.id) {
                let phrase = Exercise.pluralPhrase(for: exercise.id, name: exercise.name)
                let amount = exercise.unit == .reps ? "\(eased.newTarget) reps" : "\(eased.newTarget) seconds"
                showConfirmation("\(phrase.prefix(1).uppercased() + phrase.dropFirst()) are now \(eased.newLevel.rawValue): \(amount)")
                try? await Task.sleep(nanoseconds: 1_600_000_000)
            }
            dismiss(animated: !Theme.reduceMotion)
        }
    }

    /// The banner beat the screen to it. Say so plainly, then get out of the way.
    private func showAlreadyLoggedAndDismiss() async {
        showConfirmation("This set was already logged.", color: Theme.secondaryText)
        doneButton.isEnabled = false
        skipButton.isEnabled = false
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        dismiss(animated: !Theme.reduceMotion)
    }

    private func showConfirmation(_ text: String, color: UIColor = Theme.accent) {
        confirmationLabel.text = text
        confirmationLabel.textColor = color
        confirmationLabel.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    private func showCheckAndDismiss() async {
        let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        check.tintColor = Theme.accent
        check.translatesAutoresizingMaskIntoConstraints = false
        check.contentMode = .scaleAspectFit
        check.isAccessibilityElement = false
        view.addSubview(check)
        NSLayoutConstraint.activate([
            check.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            check.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            check.widthAnchor.constraint(equalToConstant: 120),
            check.heightAnchor.constraint(equalToConstant: 120)
        ])
        UIAccessibility.post(notification: .announcement, argument: "Logged")
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        if !Theme.reduceMotion {
            check.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.4) {
                check.transform = .identity
            }
        }
        try? await Task.sleep(nanoseconds: 600_000_000)
        dismiss(animated: !Theme.reduceMotion)
    }

    @objc private func dismissSelf() {
        stopTimer()
        dismiss(animated: !Theme.reduceMotion)
    }
}

/// The countdown ring behind the numerals. A plain CAShapeLayer, animated by
/// the one-second timer rather than a display link, because a 60 Hz redraw for
/// a whole-second countdown is wasted battery.
final class CountdownRingView: UIView {
    var progress: Double = 0 {
        didSet { updateProgress() }
    }

    var showsTrack = true {
        didSet { track.isHidden = !showsTrack; bar.isHidden = !showsTrack }
    }

    private let track = CAShapeLayer()
    private let bar = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        for layer in [track, bar] {
            layer.fillColor = UIColor.clear.cgColor
            layer.lineCap = .round
            layer.lineWidth = 10
            self.layer.addSublayer(layer)
        }
        track.strokeColor = UIColor(white: 1, alpha: 0.1).cgColor
        bar.strokeColor = Theme.accent.cgColor
        bar.strokeEnd = 0
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = bar.lineWidth / 2 + 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = UIBezierPath(
            arcCenter: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        track.path = path.cgPath
        bar.path = path.cgPath
        track.frame = bounds
        bar.frame = bounds
    }

    private func updateProgress() {
        let clamped = max(0, min(1, progress))
        if Theme.reduceMotion {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            bar.strokeEnd = clamped
            CATransaction.commit()
        } else {
            bar.strokeEnd = clamped
        }
    }
}
