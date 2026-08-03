import Foundation
import Observation
import JellyfinAPI

/// State machine driving the Live TV player. Owns:
/// - The current Jellyfin live-stream session (id + URL)
/// - AVPlayer lifecycle, abstracted via `PlayerHost`
/// - Network monitoring as a secondary signal, abstracted via `NetworkMonitor`
/// - Auto-retry policy: retry once on transient failures; reset counter on
///   every successful transition to `.playing` AND on user-initiated channel
///   change. DirectPlay-fallback is a separate one-shot retry that flips
///   `forceTranscoding=true` if the first attempt produced a direct-stream
///   URL AVPlayer couldn't decode.
/// - Channel up/down with 400ms debounce.
/// - Stream close on dismiss (held in a static `Set<Task>` so view-dealloc
///   doesn't kill it mid-flight).
@MainActor
@Observable
public final class PlayerViewModel {

    // MARK: - State

    public enum State: Equatable, Sendable {
        case idle
        case resolving(LiveTvChannel)
        case splash(LiveTvChannel, LiveStreamPlayback)
        case buffering(LiveTvChannel, LiveStreamPlayback)
        case playing(LiveTvChannel, LiveStreamPlayback)
        case reconnecting(LiveTvChannel, LiveStreamPlayback)
        case error(channel: LiveTvChannel, message: String, detail: String?)

        public var channel: LiveTvChannel? {
            switch self {
            case .idle: return nil
            case .resolving(let c): return c
            case .splash(let c, _): return c
            case .buffering(let c, _): return c
            case .playing(let c, _): return c
            case .reconnecting(let c, _): return c
            case .error(let c, _, _): return c
            }
        }

        public var playback: LiveStreamPlayback? {
            switch self {
            case .splash(_, let p), .buffering(_, let p), .playing(_, let p), .reconnecting(_, let p):
                return p
            default:
                return nil
            }
        }

        /// True when the splash overlay should be visible.
        public var showsSplash: Bool {
            switch self {
            case .resolving, .splash, .buffering: return true
            default: return false
            }
        }
    }

    // MARK: - Public state

    public private(set) var state: State = .idle

    /// Whether the channel-info HUD is currently shown over playing video.
    /// Auto-shown for ~3s on each tune; refreshed on remote-tap.
    public private(set) var hudVisible: Bool = false

    /// The full ordered channel list — used for channel up/down.
    public var channels: [LiveTvChannel]

    /// Optional program info passed in for the splash + HUD. Updated when
    /// channel changes if the new channel has `currentProgram`.
    public private(set) var currentProgram: LiveTvProgram?

    public let serverURL: URL

    // MARK: - Dependencies

    public typealias OpenStream = @MainActor (LiveTvChannel, _ forceTranscoding: Bool) async throws -> LiveStreamPlayback
    public typealias CloseStream = @MainActor (String) async -> Void

    private let openStream: OpenStream
    private let closeStream: CloseStream
    private let host: any PlayerHost
    private let networkMonitor: any NetworkMonitor

    // MARK: - Internal state

    private var retryCount: Int = 0
    private var directPlayFallbackUsed: Bool = false
    private var debounceTask: Task<Void, Never>?
    private var pendingChannel: LiveTvChannel?
    private var bufferEmptyStartedAt: Date?
    private var reconnectTimeoutTask: Task<Void, Never>?
    private var hudHideTask: Task<Void, Never>?
    private var observationTasks: [Task<Void, Never>] = []
    /// The Task created in init to tune the initial channel. Cancelled on dismiss.
    private var initTuneTask: Task<Void, Never>?
    /// Guard against re-entrant dismiss() calls (Menu press + onDisappear backstop).
    private var isDismissed: Bool = false

    /// Keeps in-flight closeStream tasks alive past view-dealloc so the
    /// server-side session is actually torn down. Tasks remove themselves
    /// from the set on completion.
    private static var inFlightCloseTasks: Set<Task<Void, Never>> = []

    // Debounce window for rapid channel up/down presses.
    private let debounceMillis: UInt64 = 400_000_000
    // Buffer-empty must persist for >5s before we trigger reconnect.
    private let bufferEmptyThresholdSeconds: TimeInterval = 5
    // Reconnect must succeed within 10s or escalate to error card.
    private let reconnectTimeoutSeconds: TimeInterval = 10

    // MARK: - Init

    public init(
        initialChannel: LiveTvChannel,
        channels: [LiveTvChannel],
        serverURL: URL,
        program: LiveTvProgram?,
        openStream: @escaping OpenStream,
        closeStream: @escaping CloseStream,
        host: any PlayerHost,
        networkMonitor: any NetworkMonitor
    ) {
        self.channels = channels
        self.serverURL = serverURL
        self.currentProgram = program
        self.openStream = openStream
        self.closeStream = closeStream
        self.host = host
        self.networkMonitor = networkMonitor
        self.state = .idle

        startObservers()
        initTuneTask = Task { await tune(initialChannel, isUserInitiated: true) }
    }

    // MARK: - Public API

    /// Tune to a specific channel. Closes the current session, opens a new one,
    /// transitions through resolving → splash → buffering → playing.
    public func tune(_ channel: LiveTvChannel, isUserInitiated: Bool = true) async {
        if isUserInitiated {
            retryCount = 0
            directPlayFallbackUsed = false
        }
        await closeCurrentStreamIfNeeded()

        state = .resolving(channel)
        currentProgram = channel.currentProgram
        await openAndStart(channel: channel, forceTranscoding: false)
    }

    /// Channel-up debounced — if pressed rapidly multiple times, only the
    /// last press triggers a tune.
    public func channelUp() {
        scheduleDebouncedTune { current, channels in
            ChannelOrdering.next(after: current, in: channels)
        }
    }

    /// Channel-down debounced.
    public func channelDown() {
        scheduleDebouncedTune { current, channels in
            ChannelOrdering.previous(before: current, in: channels)
        }
    }

    /// User-triggered retry from the error card.
    public func retry() async {
        guard let channel = state.channel else { return }
        retryCount = 0
        directPlayFallbackUsed = false
        await tune(channel, isUserInitiated: true)
    }

    /// Show the channel-info HUD for ~3s.
    public func pulseHUD() {
        hudVisible = true
        hudHideTask?.cancel()
        hudHideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.hudVisible = false
        }
    }

    /// Tear everything down — called on view dismiss. Schedules the close
    /// call on a long-lived task, stops the network monitor, tears down the
    /// player host.
    ///
    /// Idempotent: safe to call multiple times (Menu-press handler + onDisappear
    /// backstop may both fire). Only the first call performs teardown.
    public func dismiss() {
        guard !isDismissed else { return }
        isDismissed = true

        initTuneTask?.cancel()
        initTuneTask = nil
        debounceTask?.cancel()
        reconnectTimeoutTask?.cancel()
        hudHideTask?.cancel()
        observationTasks.forEach { $0.cancel() }
        // Capture liveStreamId synchronously BEFORE clearing state — otherwise
        // the async close call reads state.playback after we've already
        // transitioned to .idle and finds nothing to close.
        if let id = state.playback?.liveStreamId {
            scheduleClose(liveStreamId: id)
        }
        networkMonitor.stop()
        host.tearDown()
        state = .idle
    }

    // MARK: - Internal: tuning & state transitions

    private func openAndStart(channel: LiveTvChannel, forceTranscoding: Bool) async {
        do {
            let playback = try await openStream(channel, forceTranscoding)
            // The state may have changed while awaiting (user pressed channel
            // up again). If so, abandon this open's result.
            guard case .resolving(let resolvingChannel) = state, resolvingChannel.id == channel.id else {
                // The new tune already kicked off — close the just-opened
                // stream so we don't leak it.
                if let id = playback.liveStreamId {
                    scheduleClose(liveStreamId: id)
                }
                return
            }
            state = .splash(channel, playback)
            host.replaceItem(url: playback.playbackURL)
        } catch {
            await handleOpenFailure(channel: channel, error: error, forceTranscoding: forceTranscoding)
        }
    }

    private func handleOpenFailure(channel: LiveTvChannel, error: Error, forceTranscoding: Bool) async {
        JellytvLog.player.error("PlayerViewModel: openStream failed for \(channel.id, privacy: .public): \(String(describing: error), privacy: .public)")
        // First failure on the original (no-fallback) path: try forceTranscoding.
        if !forceTranscoding && !directPlayFallbackUsed {
            directPlayFallbackUsed = true
            JellytvLog.player.info("PlayerViewModel: retrying with forceTranscoding=true")
            await openAndStart(channel: channel, forceTranscoding: true)
            return
        }
        // Otherwise consume one general retry budget.
        if retryCount < 1 {
            retryCount += 1
            JellytvLog.player.info("PlayerViewModel: auto-retry (count=\(self.retryCount))")
            await openAndStart(channel: channel, forceTranscoding: directPlayFallbackUsed)
            return
        }
        // No more retries — show the error card.
        let nsError = error as NSError
        state = .error(channel: channel, message: "Couldn't tune \(channel.name)", detail: nsError.localizedDescription)
    }

    private func handlePlaybackFailure(error: PlayerHostError?) async {
        guard let channel = state.channel, state.playback != nil else { return }
        // Treat mid-playback failure as one retry budget — same policy as
        // open failure. Reset DirectPlay fallback so we don't double-flip.
        if retryCount < 1 {
            retryCount += 1
            JellytvLog.player.info("PlayerViewModel: AVPlayer failure, retrying (count=\(self.retryCount))")
            await closeCurrentStreamIfNeeded()
            state = .resolving(channel)
            await openAndStart(channel: channel, forceTranscoding: directPlayFallbackUsed)
            return
        }
        let detail = error?.localizedDescription
        state = .error(channel: channel, message: "Playback stopped", detail: detail)
    }

    // MARK: - Internal: channel up/down debounce

    private func scheduleDebouncedTune(
        _ resolver: @escaping @MainActor (LiveTvChannel, [LiveTvChannel]) -> LiveTvChannel?
    ) {
        guard let current = state.channel ?? pendingChannel else { return }
        // Compute candidate from resolver, store, restart timer.
        let candidate = resolver(pendingChannel ?? current, channels)
        guard let candidate else { return }
        pendingChannel = candidate
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self, debounceMillis] in
            try? await Task.sleep(nanoseconds: debounceMillis)
            guard let self, !Task.isCancelled else { return }
            guard let final = self.pendingChannel else { return }
            self.pendingChannel = nil
            await self.tune(final, isUserInitiated: true)
            self.pulseHUD()
        }
    }

    // MARK: - Internal: stream close lifecycle

    private func closeCurrentStreamIfNeeded() async {
        guard let oldId = state.playback?.liveStreamId else { return }
        scheduleClose(liveStreamId: oldId)
    }

    private func scheduleClose(liveStreamId: String) {
        let close = closeStream
        let task = Task { @MainActor in
            await close(liveStreamId)
        }
        Self.registerCloseTask(task)
    }

    @MainActor
    private static func registerCloseTask(_ task: Task<Void, Never>) {
        inFlightCloseTasks.insert(task)
        Task { @MainActor in
            await task.value
            inFlightCloseTasks.remove(task)
        }
    }

    // MARK: - Internal: observer plumbing

    private func startObservers() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll(keepingCapacity: true)
        observationTasks.append(Task { @MainActor [weak self] in await self?.consumeStatusStream() })
        observationTasks.append(Task { @MainActor [weak self] in await self?.consumeReadyForDisplayStream() })
        observationTasks.append(Task { @MainActor [weak self] in await self?.consumeBufferEmptyStream() })
        observationTasks.append(Task { @MainActor [weak self] in await self?.consumeFailedToPlayStream() })
        observationTasks.append(Task { @MainActor [weak self] in await self?.consumeNetworkStream() })
        networkMonitor.start()
    }

    private func consumeStatusStream() async {
        for await rawStatus in host.statusStream {
            // .failed = 2
            if rawStatus == 2 {
                await handlePlaybackFailure(error: nil)
            }
        }
    }

    private func consumeReadyForDisplayStream() async {
        for await ready in host.readyForDisplayStream where ready {
            // First frame rendered — exit splash.
            switch state {
            case .splash(let c, let p), .buffering(let c, let p):
                state = .playing(c, p)
                retryCount = 0
                pulseHUD()
            default:
                break
            }
        }
    }

    private func consumeBufferEmptyStream() async {
        for await empty in host.bufferEmptyStream {
            if empty {
                bufferEmptyStartedAt = Date()
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64((self?.bufferEmptyThresholdSeconds ?? 5) * 1_000_000_000))
                    guard let self else { return }
                    // If still empty after threshold, switch to reconnecting.
                    guard let started = self.bufferEmptyStartedAt,
                          Date().timeIntervalSince(started) >= self.bufferEmptyThresholdSeconds else {
                        return
                    }
                    if case .playing(let c, let p) = self.state {
                        self.state = .reconnecting(c, p)
                        self.scheduleReconnectEscalation()
                    }
                }
            } else {
                bufferEmptyStartedAt = nil
                reconnectTimeoutTask?.cancel()
                if case .reconnecting(let c, let p) = state {
                    state = .playing(c, p)
                }
            }
        }
    }

    private func consumeFailedToPlayStream() async {
        for await error in host.failedToPlayStream {
            await handlePlaybackFailure(error: error)
        }
    }

    private func consumeNetworkStream() async {
        for await satisfied in networkMonitor.pathSatisfiedStream {
            // NetworkMonitor is a SECONDARY signal — only act if we're already
            // reconnecting. This avoids fighting AVPlayer's own HLS retry.
            if satisfied, case .reconnecting(let c, _) = state {
                JellytvLog.player.info("PlayerViewModel: network restored during reconnect, retrying")
                await tune(c, isUserInitiated: false)
            }
        }
    }

    private func scheduleReconnectEscalation() {
        reconnectTimeoutTask?.cancel()
        reconnectTimeoutTask = Task { @MainActor [weak self, reconnectTimeoutSeconds] in
            try? await Task.sleep(nanoseconds: UInt64(reconnectTimeoutSeconds * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            if case .reconnecting(let c, _) = self.state {
                self.state = .error(channel: c, message: "Lost connection", detail: "The stream couldn't recover after \(Int(reconnectTimeoutSeconds))s.")
            }
        }
    }
}
