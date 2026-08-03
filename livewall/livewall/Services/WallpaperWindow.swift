import AppKit
import AVFoundation
import os

final class WallpaperPlayerView: NSView {
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var notificationObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?

    // Stall detection state. The KVO closure for `timeControlStatus` hops to
    // `@MainActor` before touching any of these — they are only mutated from
    // the main actor.
    private var stallObservation: NSKeyValueObservation?
    private var hasPlayedAtLeastOnce: Bool = false
    private var stallTask: Task<Void, Never>?
    private var lastStallReport: Date?

    /// Minimum time the player must be in `.waitingToPlayAtSpecifiedRate`
    /// before we consider it a stall worth surfacing to the user.
    private static let stallThreshold: Duration = .seconds(15)
    /// Don't surface more than one stall alert per player within this window.
    private static let stallReportCooldown: TimeInterval = 60

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        autoresizingMask = [.width, .height]

        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        self.layer?.addSublayer(layer)
        playerLayer = layer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func play(url: URL) {
        stop()

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.actionAtItemEnd = .none
        newPlayer.isMuted = true

        playerLayer?.player = newPlayer
        player = newPlayer

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            playerItem.seek(to: .zero) { _ in
                newPlayer.play()
            }
        }

        // Observe the item's playback readiness so we can surface failures.
        // Token is stored as a property so the observation stays alive.
        statusObservation = playerItem.observe(\.status, options: [.new]) { item, _ in
            switch item.status {
            case .failed:
                let message = item.error?.localizedDescription ?? "Unknown playback error"
                AppLogger.playback.error("Playback failed: \(message, privacy: .public)")
                AppErrorPresenter.report(
                    title: "Playback Failed",
                    message: message,
                    recoverySuggestion: "The file may be corrupt or use an unsupported codec."
                )
            case .readyToPlay:
                AppLogger.playback.debug("Player item ready")
            case .unknown:
                break
            @unknown default:
                break
            }
        }

        // Observe `timeControlStatus` to surface silent stalls. The KVO
        // callback fires on an arbitrary thread, so it must hop to the main
        // actor before touching any view state.
        stallObservation = newPlayer.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in
                self?.handleTimeControlStatus(status)
            }
        }

        newPlayer.play()
    }

    @MainActor
    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            hasPlayedAtLeastOnce = true
            cancelStallTimer()
        case .waitingToPlayAtSpecifiedRate:
            // Suppress the very first buffering pass — every newly created
            // player enters this state before the first frame is decoded.
            guard hasPlayedAtLeastOnce else { return }
            armStallTimer()
        case .paused:
            cancelStallTimer()
        @unknown default:
            break
        }
    }

    @MainActor
    private func armStallTimer() {
        cancelStallTimer()
        stallTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: WallpaperPlayerView.stallThreshold)
            guard !Task.isCancelled, let self else { return }
            // Re-check the player is still wedged before we cry wolf.
            if self.player?.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                self.reportStall()
            }
        }
    }

    @MainActor
    private func cancelStallTimer() {
        stallTask?.cancel()
        stallTask = nil
    }

    @MainActor
    private func reportStall() {
        if let last = lastStallReport, Date().timeIntervalSince(last) < WallpaperPlayerView.stallReportCooldown {
            return
        }
        lastStallReport = Date()
        AppLogger.playback.warning("Wallpaper playback stalled (waiting to play)")
        AppErrorPresenter.report(
            title: "Playback Stalled",
            message: "A wallpaper has been buffering for an unusually long time.",
            recoverySuggestion: "Check your network connection."
        )
    }

    func pause() {
        player?.pause()
    }

    func resume() {
        player?.play()
    }

    func stop() {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        stallObservation?.invalidate()
        stallObservation = nil
        cancelStallTimer()
        hasPlayedAtLeastOnce = false
        lastStallReport = nil
        player?.pause()
        playerLayer?.player = nil
        player = nil
    }

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }
}

final class WallpaperWindow: NSWindow {
    let playerView: WallpaperPlayerView

    init(contentRect: CGRect) {
        playerView = WallpaperPlayerView(frame: NSRect(origin: .zero, size: contentRect.size))

        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        configureWindow()
    }

    private func configureWindow() {
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        isOpaque = true
        backgroundColor = .black
        ignoresMouseEvents = true
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        hasShadow = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = false
        canHide = false
        hidesOnDeactivate = false
        animationBehavior = .none

        contentView = playerView
    }

    func play(url: URL) {
        playerView.play(url: url)
    }

    func pause() {
        playerView.pause()
    }

    func resume() {
        playerView.resume()
    }

    func stop() {
        playerView.stop()
    }

    func updateFrame(_ rect: CGRect) {
        setFrame(rect, display: true)
    }
}
