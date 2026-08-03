import Foundation

public protocol JellyfinClientAPI: Sendable {
    /// Set or change the server URL. Pass nil to clear.
    func setServerURL(_ url: URL?) async

    /// Get the current server URL, if configured.
    func currentServerURL() async -> URL?

    /// Set or clear the access token used by authenticated calls.
    func setAccessToken(_ token: String?) async

    // MARK: - Auth

    func getPublicSystemInfo() async throws -> PublicSystemInfo
    func authenticateByName(username: String, password: String) async throws -> AuthenticationResult

    func quickConnectEnabled() async throws -> Bool
    func quickConnectInitiate() async throws -> QuickConnectResult
    func quickConnectStatus(secret: String) async throws -> QuickConnectResult
    func authenticateWithQuickConnect(secret: String) async throws -> AuthenticationResult

    func currentUser() async throws -> UserDto
    func logout() async throws

    // MARK: - Home

    /// GET /UserViews — returns libraries (collections like Movies, TV Shows, etc.)
    func userViews() async throws -> [BaseItemDto]

    /// GET /UserItems/Resume?limit=... — Continue Watching
    func resumeItems(limit: Int) async throws -> [BaseItemDto]

    /// GET /Shows/NextUp?limit=... — Next Up episodes
    func nextUp(limit: Int) async throws -> [BaseItemDto]

    /// GET /Items/Latest?parentId=...&limit=... — Latest items per library
    func latestItems(parentId: String?, limit: Int) async throws -> [BaseItemDto]

    // MARK: - Live TV

    /// GET /LiveTv/Channels — list of TV channels (default: all, sorted by name,
    /// no current-program enrichment).
    func liveTvChannels() async throws -> [LiveTvChannel]

    /// GET /LiveTv/Channels — filtered + optionally enriched with the
    /// currently-airing program on each channel (`addCurrentProgram=true`).
    /// Powers the "On Now" landing as well as the favorites / category filters.
    func liveTvChannels(
        filters: LiveTvChannelFilters,
        addCurrentProgram: Bool
    ) async throws -> [LiveTvChannel]

    /// GET /LiveTv/Programs — EPG entries for the given channels in the time window.
    /// `minStartDate` and `maxStartDate` filter on each program's start time.
    /// To capture programs already in progress at the window start, callers should
    /// pass a `minStartDate` somewhat earlier than the visible window start.
    func liveTvPrograms(
        channelIds: [String],
        minStartDate: Date,
        maxStartDate: Date
    ) async throws -> [LiveTvProgram]

    /// GET /LiveTv/Programs — full filter surface (genre / category filters, sort).
    func liveTvPrograms(
        channelIds: [String]?,
        minStartDate: Date?,
        maxStartDate: Date?,
        filters: LiveTvProgramFilters
    ) async throws -> [LiveTvProgram]

    /// GET /LiveTv/Programs/Recommended — server-curated upcoming program list.
    /// Used for the "Recommended for You" shelf on the Live TV landing.
    func liveTvRecommendedPrograms(
        filters: LiveTvProgramFilters
    ) async throws -> [LiveTvProgram]

    /// GET /LiveTv/Programs/{programId} — detailed info for a single program.
    func liveTvProgram(programId: String) async throws -> LiveTvProgram

    /// GET /LiveTv/Recordings — completed and in-progress recordings.
    /// Pass `isInProgress=true` to fetch only currently-recording timers.
    func liveTvRecordings(
        isInProgress: Bool?,
        seriesTimerId: String?,
        limit: Int?
    ) async throws -> [BaseItemDto]

    /// DELETE /LiveTv/Recordings/{recordingId}.
    func deleteLiveTvRecording(recordingId: String) async throws

    /// GET /LiveTv/Timers — one-shot scheduled recordings.
    func liveTvTimers() async throws -> [TimerInfoDto]

    /// GET /LiveTv/SeriesTimers — recurring (series) recording rules.
    func liveTvSeriesTimers() async throws -> [SeriesTimerInfoDto]

    /// GET /LiveTv/Timers/Defaults?programId=... — server-suggested defaults
    /// for a new timer. Submit the result back to `createLiveTvTimer` to record.
    func liveTvTimerDefaults(programId: String?) async throws -> Data

    /// POST /LiveTv/Timers — schedule a one-shot recording. `body` is the JSON
    /// returned by `liveTvTimerDefaults` (potentially mutated by the caller).
    func createLiveTvTimer(body: Data) async throws

    /// POST /LiveTv/SeriesTimers — schedule a series recording.
    func createLiveTvSeriesTimer(body: Data) async throws

    /// DELETE /LiveTv/Timers/{timerId} — cancel a one-shot timer.
    func cancelLiveTvTimer(timerId: String) async throws

    /// DELETE /LiveTv/SeriesTimers/{timerId} — cancel a series timer.
    func cancelLiveTvSeriesTimer(timerId: String) async throws

    /// POST /UserFavoriteItems/{itemId} — mark an item (e.g. a channel) as a
    /// favorite for the current user.
    func setFavorite(itemId: String, isFavorite: Bool) async throws

    /// POST /LiveTv/LiveStreams/Open — open a live TV stream for the given channel.
    /// Returns a `LiveStreamPlayback` with a fully-resolved playback URL (the
    /// access token is baked into the URL — callers should never need to add it).
    func liveTvOpenStream(channelId: String) async throws -> LiveStreamPlayback
}

// MARK: - Live TV stream extensions
//
// These methods are intentionally added in the default-implementation extension
// rather than the protocol body so existing explicit conformers (FakeJellyfinClient,
// MockJellyfinClient) continue to compile without per-conformer stubs. Conformers
// that need real behavior (the actor `JellyfinClient`) override; everything else
// gets a sensible default.

// Default forwarding so existing conformers (tests, mocks) keep compiling
// after the protocol grew. New conformers should override every method.
public extension JellyfinClientAPI {
    func liveTvChannels(
        filters: LiveTvChannelFilters,
        addCurrentProgram: Bool
    ) async throws -> [LiveTvChannel] {
        try await liveTvChannels()
    }

    func liveTvPrograms(
        channelIds: [String]?,
        minStartDate: Date?,
        maxStartDate: Date?,
        filters: LiveTvProgramFilters
    ) async throws -> [LiveTvProgram] {
        []
    }

    func liveTvRecommendedPrograms(
        filters: LiveTvProgramFilters
    ) async throws -> [LiveTvProgram] {
        []
    }

    func liveTvProgram(programId: String) async throws -> LiveTvProgram {
        throw JellyfinError.notConfigured
    }

    func liveTvRecordings(
        isInProgress: Bool?,
        seriesTimerId: String?,
        limit: Int?
    ) async throws -> [BaseItemDto] {
        []
    }

    func deleteLiveTvRecording(recordingId: String) async throws {}

    func liveTvTimers() async throws -> [TimerInfoDto] { [] }

    func liveTvSeriesTimers() async throws -> [SeriesTimerInfoDto] { [] }

    func liveTvTimerDefaults(programId: String?) async throws -> Data { Data() }

    func createLiveTvTimer(body: Data) async throws {}

    func createLiveTvSeriesTimer(body: Data) async throws {}

    func cancelLiveTvTimer(timerId: String) async throws {}

    func cancelLiveTvSeriesTimer(timerId: String) async throws {}

    func setFavorite(itemId: String, isFavorite: Bool) async throws {}

    /// Open a live stream, optionally forcing the server to transcode (skipping
    /// any DirectPlay path). Used by the player as a fallback when DirectPlay
    /// produces a URL AVPlayer can't consume for live media.
    /// Default impl ignores the flag and forwards to `liveTvOpenStream(channelId:)`.
    func liveTvOpenStream(
        channelId: String,
        forceTranscoding: Bool
    ) async throws -> LiveStreamPlayback {
        try await liveTvOpenStream(channelId: channelId)
    }

    /// POST /LiveStreams/Close?liveStreamId=… — best-effort tell the server to
    /// kill the transcoder session. Saves server CPU + frees HDHomeRun tuners
    /// for fast channel-switching. Default impl is a no-op so mocks compile.
    func liveTvCloseStream(liveStreamId: String) async throws {}
}
