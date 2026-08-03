import AppKit
import Combine
import IOKit.ps
import os

enum WallpaperApplyScope {
    case allDisplays
    case specificDisplay(displayID: String)
}

final class WallpaperEngine: ObservableObject {
    static let shared = WallpaperEngine(displayManager: .shared)

    @Published var activeWallpapers: [String: Wallpaper] = [:]
    @Published var isPaused = false

    private var windows: [String: WallpaperWindow] = [:]
    private var displayManager: DisplayManager
    private var powerPollTimer: Timer?

    init(displayManager: DisplayManager) {
        self.displayManager = displayManager
        setupBatteryMonitoring()
    }

    deinit {
        powerPollTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    static func makeDefault() -> WallpaperEngine {
        WallpaperEngine(displayManager: .shared)
    }

    // MARK: - Apply / set

    func apply(_ wallpaper: Wallpaper, scope: WallpaperApplyScope) {
        guard ensureAvailable(wallpaper) else { return }

        AppLogger.engine.debug("apply \(wallpaper.title, privacy: .public) to \(String(describing: scope), privacy: .public), displays=\(self.displayManager.displays.count, privacy: .public)")

        switch scope {
        case .allDisplays:
            for display in displayManager.displays {
                setWallpaperInternal(wallpaper, forDisplay: display.id)
            }
        case .specificDisplay(let displayID):
            setWallpaperInternal(wallpaper, forDisplay: displayID)
        }
    }

    /// Public entry point for single-display apply (from the detail view).
    /// Runs the same availability check as `apply(_:scope:)`.
    func setWallpaper(_ wallpaper: Wallpaper, forDisplay displayID: String) {
        guard ensureAvailable(wallpaper) else { return }
        setWallpaperInternal(wallpaper, forDisplay: displayID)
    }

    /// Internal hot-path — no availability check. Only call after `ensureAvailable`
    /// has been verified once at the top level.
    private func setWallpaperInternal(_ wallpaper: Wallpaper, forDisplay displayID: String) {
        activeWallpapers[displayID] = wallpaper
        updateWindow(forDisplay: displayID, wallpaper: wallpaper)
    }

    /// Returns true if the wallpaper's backing file is reachable. For stale
    /// local wallpapers, logs a warning and surfaces a single user-visible
    /// error (deduped by the presenter).
    private func ensureAvailable(_ wallpaper: Wallpaper) -> Bool {
        if wallpaper.isLocal,
           let url = wallpaper.localFileURL,
           !FileManager.default.fileExists(atPath: url.path) {
            AppLogger.engine.warning("Stale local wallpaper: \(wallpaper.title, privacy: .public) at \(url.path, privacy: .public)")
            AppErrorPresenter.report(
                title: "Wallpaper File Missing",
                message: "\"\(wallpaper.title)\" was moved or deleted since you imported it.",
                recoverySuggestion: "Remove it from your library or re-import the file."
            )
            return false
        }
        return true
    }

    // MARK: - Playback control

    func pauseAll() {
        isPaused = true
        windows.values.forEach { $0.pause() }
    }

    func resumeAll() {
        isPaused = false
        windows.values.forEach { $0.resume() }
    }

    func stopAll() {
        windows.values.forEach { $0.stop() }
        windows.values.forEach { $0.orderOut(nil) }
        windows.removeAll()
        activeWallpapers.removeAll()
    }

    /// Removes the wallpaper from a specific display, hiding its window.
    func stop(forDisplay displayID: String) {
        if let window = windows[displayID] {
            window.stop()
            window.orderOut(nil)
            windows.removeValue(forKey: displayID)
        }
        activeWallpapers.removeValue(forKey: displayID)
    }

    func refreshDisplays() {
        displayManager.refreshDisplays()
        rebuildWindows()
    }

    var displays: [DisplayInfo] {
        displayManager.displays
    }

    // MARK: - Window management

    private func updateWindow(forDisplay displayID: String, wallpaper: Wallpaper) {
        guard let display = displayManager.displays.first(where: { $0.id == displayID }) else {
            AppLogger.engine.warning("No display found for id \(displayID, privacy: .public)")
            return
        }

        AppLogger.engine.debug("updateWindow display=\(displayID, privacy: .public)")

        let window: WallpaperWindow
        if let existing = windows[displayID] {
            window = existing
        } else {
            window = WallpaperWindow(contentRect: display.frame)
            windows[displayID] = window
        }

        window.updateFrame(display.frame)

        guard let url = resolveVideoURL(for: wallpaper) else {
            AppLogger.engine.error("No reachable video URL for wallpaper \(wallpaper.title, privacy: .public)")
            AppErrorPresenter.report(
                title: "Can't Play This Wallpaper",
                message: "The video source for \"\(wallpaper.title)\" isn't reachable.",
                recoverySuggestion: "Try a different wallpaper, or re-import it if it's a local file."
            )
            return
        }

        window.play(url: url)
        window.orderBack(nil)
    }

    /// Resolves the playable URL for a wallpaper: local file → cached download → remote → raw videoURL.
    private func resolveVideoURL(for wallpaper: Wallpaper) -> URL? {
        if let localURL = wallpaper.localFileURL {
            return localURL
        }

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let downloadDir = support.appendingPathComponent("livewall/wallpapers", isDirectory: true)
        let cachedURL = downloadDir.appendingPathComponent("\(wallpaper.id).mp4")

        if FileManager.default.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }
        if let remoteURL = wallpaper.remoteURL {
            return remoteURL
        }
        if let videoURL = URL(string: wallpaper.videoURL) {
            return videoURL
        }
        return nil
    }

    private func rebuildWindows() {
        let currentDisplayIDs = Set(displayManager.displays.map { $0.id })
        let staleIDs = Set(windows.keys).subtracting(currentDisplayIDs)

        for staleID in staleIDs {
            AppLogger.engine.info("Display disconnected: \(staleID, privacy: .public)")
            windows[staleID]?.stop()
            windows[staleID]?.close()
            windows.removeValue(forKey: staleID)
            activeWallpapers.removeValue(forKey: staleID)
        }

        for display in displayManager.displays {
            if let wallpaper = activeWallpapers[display.id] {
                updateWindow(forDisplay: display.id, wallpaper: wallpaper)
            }
        }
    }

    // MARK: - Battery monitoring

    private func setupBatteryMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePowerChange()
        }

        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePowerChange()
        }

        // Poll every 30s to catch plug/unplug events between notifications.
        powerPollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.handlePowerChange()
        }
    }

    private func handlePowerChange() {
        guard SettingsManager.shared.pauseOnBattery else { return }

        let onBattery = ProcessInfo.processInfo.isLowPowerModeEnabled || isOnBattery()

        if onBattery {
            pauseAll()
        } else {
            resumeAll()
        }
    }

    private func isOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return false
        }
        guard let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let type = desc[kIOPSPowerSourceStateKey] as? String else {
                continue
            }
            if type == kIOPSOffLineValue {
                return true
            }
        }
        return false
    }
}
