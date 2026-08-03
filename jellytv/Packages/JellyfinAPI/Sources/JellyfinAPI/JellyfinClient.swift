import Foundation

@available(tvOS 15.0, macOS 12.0, *)
public actor JellyfinClient: JellyfinClientAPI {

    // MARK: - State

    private var serverURL: URL?
    private var accessToken: String?
    /// Lazily fetched + cached user id. Some endpoints (e.g. PlaybackInfo)
    /// require it as a query parameter even though the auth header already
    /// identifies the user. Cleared when access token changes.
    private var cachedUserId: String?

    // MARK: - Immutable configuration

    private let deviceId: String
    private let clientName: String
    private let clientVersion: String
    private let deviceName: String

    // MARK: - Networking

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Init

    public init(
        deviceId: String,
        clientName: String = "JellyTV",
        clientVersion: String = "1.0",
        deviceName: String = "Apple TV",
        session: URLSession? = nil
    ) {
        self.deviceId = deviceId
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.deviceName = deviceName

        if let session {
            self.session = session
        } else {
            self.session = URLSession(configuration: .ephemeral)
        }

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        self.encoder = JSONEncoder()
    }

    // MARK: - Protocol: State setters

    public func setServerURL(_ url: URL?) async {
        serverURL = url
    }

    public nonisolated func currentServerURL() async -> URL? {
        await getServerURL()
    }

    private func getServerURL() -> URL? {
        return serverURL
    }

    public func setAccessToken(_ token: String?) async {
        accessToken = token
        cachedUserId = nil
    }

    /// Returns the current user id, caching it on the actor. Throws if not
    /// signed in. Used by endpoints that require a `userId` query param.
    private func resolveUserId() async throws -> String {
        if let cachedUserId { return cachedUserId }
        let user = try await currentUser()
        cachedUserId = user.id
        return user.id
    }

    // MARK: - Protocol: Endpoints

    public func getPublicSystemInfo() async throws -> PublicSystemInfo {
        let request = try buildRequest(path: "/System/Info/Public")
        return try await send(request, as: PublicSystemInfo.self)
    }

    public func authenticateByName(username: String, password: String) async throws -> AuthenticationResult {
        let body = try encoder.encode(AuthenticationRequest(username: username, pw: password))
        let request = try buildRequest(path: "/Users/AuthenticateByName", method: "POST", body: body)
        return try await send(request, as: AuthenticationResult.self)
    }

    public func quickConnectEnabled() async throws -> Bool {
        let request = try buildRequest(path: "/QuickConnect/Enabled")
        return try await send(request, as: Bool.self)
    }

    public func quickConnectInitiate() async throws -> QuickConnectResult {
        let request = try buildRequest(path: "/QuickConnect/Initiate", method: "POST")
        do {
            return try await send(request, as: QuickConnectResult.self)
        } catch JellyfinError.unauthenticated {
            throw JellyfinError.quickConnectDisabled
        }
    }

    public func quickConnectStatus(secret: String) async throws -> QuickConnectResult {
        let request = try buildRequest(
            path: "/QuickConnect/Connect",
            queryItems: [URLQueryItem(name: "secret", value: secret)]
        )
        do {
            return try await send(request, as: QuickConnectResult.self)
        } catch JellyfinError.http(status: 404, _) {
            throw JellyfinError.quickConnectExpired
        }
    }

    public func authenticateWithQuickConnect(secret: String) async throws -> AuthenticationResult {
        let body = try encoder.encode(QuickConnectAuthRequest(secret: secret))
        let request = try buildRequest(path: "/Users/AuthenticateWithQuickConnect", method: "POST", body: body)
        return try await send(request, as: AuthenticationResult.self)
    }

    public func currentUser() async throws -> UserDto {
        let request = try buildRequest(path: "/Users/Me")
        return try await send(request, as: UserDto.self)
    }

    public func logout() async throws {
        let request = try buildRequest(path: "/Sessions/Logout", method: "POST")
        try await sendIgnoringResponse(request)
    }

    // MARK: - Home

    public func userViews() async throws -> [BaseItemDto] {
        let request = try buildRequest(path: "/UserViews")
        let result = try await send(request, as: BaseItemDtoQueryResult.self)
        return result.items
    }

    public func resumeItems(limit: Int) async throws -> [BaseItemDto] {
        let request = try buildRequest(
            path: "/UserItems/Resume",
            queryItems: [URLQueryItem(name: "limit", value: String(limit))]
        )
        let result = try await send(request, as: BaseItemDtoQueryResult.self)
        return result.items
    }

    public func nextUp(limit: Int) async throws -> [BaseItemDto] {
        let request = try buildRequest(
            path: "/Shows/NextUp",
            queryItems: [URLQueryItem(name: "limit", value: String(limit))]
        )
        let result = try await send(request, as: BaseItemDtoQueryResult.self)
        return result.items
    }

    public func latestItems(parentId: String?, limit: Int) async throws -> [BaseItemDto] {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let parentId = parentId {
            queryItems.append(URLQueryItem(name: "parentId", value: parentId))
        }
        let request = try buildRequest(path: "/Items/Latest", queryItems: queryItems)
        return try await send(request, as: [BaseItemDto].self)
    }

    // MARK: - Live TV

    public func liveTvChannels() async throws -> [LiveTvChannel] {
        let queryItems = [
            URLQueryItem(name: "enableImages", value: "true"),
            URLQueryItem(name: "enableImageTypes", value: "Primary"),
            URLQueryItem(name: "sortBy", value: "SortName"),
            URLQueryItem(name: "sortOrder", value: "Ascending"),
        ]
        let request = try buildRequest(path: "/LiveTv/Channels", queryItems: queryItems)
        let result = try await send(request, as: LiveTvChannelQueryResult.self)
        return result.items
    }

    public func liveTvChannels(
        filters: LiveTvChannelFilters,
        addCurrentProgram: Bool
    ) async throws -> [LiveTvChannel] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "enableImages", value: "true"),
            URLQueryItem(name: "enableImageTypes", value: "Primary,Logo,Backdrop,Thumb"),
            URLQueryItem(name: "enableUserData", value: "true"),
            URLQueryItem(name: "addCurrentProgram", value: addCurrentProgram ? "true" : "false"),
        ]
        if let value = filters.sortBy {
            queryItems.append(URLQueryItem(name: "sortBy", value: value))
        }
        if let value = filters.sortOrder {
            queryItems.append(URLQueryItem(name: "sortOrder", value: value))
        }
        if let value = filters.isMovie {
            queryItems.append(URLQueryItem(name: "isMovie", value: value ? "true" : "false"))
        }
        if let value = filters.isSeries {
            queryItems.append(URLQueryItem(name: "isSeries", value: value ? "true" : "false"))
        }
        if let value = filters.isNews {
            queryItems.append(URLQueryItem(name: "isNews", value: value ? "true" : "false"))
        }
        if let value = filters.isKids {
            queryItems.append(URLQueryItem(name: "isKids", value: value ? "true" : "false"))
        }
        if let value = filters.isSports {
            queryItems.append(URLQueryItem(name: "isSports", value: value ? "true" : "false"))
        }
        if let value = filters.isFavorite {
            queryItems.append(URLQueryItem(name: "isFavorite", value: value ? "true" : "false"))
        }
        if let value = filters.isAiringNow {
            queryItems.append(URLQueryItem(name: "isAiring", value: value ? "true" : "false"))
        }
        if let value = filters.startIndex {
            queryItems.append(URLQueryItem(name: "startIndex", value: String(value)))
        }
        if let value = filters.limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(value)))
        }
        let request = try buildRequest(path: "/LiveTv/Channels", queryItems: queryItems)
        let result = try await send(request, as: LiveTvChannelQueryResult.self)
        return result.items
    }

    public func liveTvPrograms(
        channelIds: [String],
        minStartDate: Date,
        maxStartDate: Date
    ) async throws -> [LiveTvProgram] {
        if channelIds.isEmpty {
            return []
        }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        var queryItems: [URLQueryItem] = channelIds.map {
            URLQueryItem(name: "channelIds", value: $0)
        }
        queryItems.append(URLQueryItem(name: "minStartDate", value: isoFormatter.string(from: minStartDate)))
        queryItems.append(URLQueryItem(name: "maxStartDate", value: isoFormatter.string(from: maxStartDate)))
        queryItems.append(URLQueryItem(name: "sortBy", value: "StartDate"))
        queryItems.append(URLQueryItem(name: "sortOrder", value: "Ascending"))
        queryItems.append(URLQueryItem(name: "enableImages", value: "false"))
        queryItems.append(URLQueryItem(name: "enableTotalRecordCount", value: "false"))
        queryItems.append(URLQueryItem(name: "fields", value: "Overview"))
        queryItems.append(URLQueryItem(name: "limit", value: "2000"))
        let request = try buildRequest(path: "/LiveTv/Programs", queryItems: queryItems)
        let result = try await send(request, as: LiveTvProgramQueryResult.self)
        return result.items
    }

    public func liveTvPrograms(
        channelIds: [String]?,
        minStartDate: Date?,
        maxStartDate: Date?,
        filters: LiveTvProgramFilters
    ) async throws -> [LiveTvProgram] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        var queryItems: [URLQueryItem] = []
        if let channelIds, !channelIds.isEmpty {
            for id in channelIds {
                queryItems.append(URLQueryItem(name: "channelIds", value: id))
            }
        }
        if let minStartDate {
            queryItems.append(URLQueryItem(name: "minStartDate", value: isoFormatter.string(from: minStartDate)))
        }
        if let maxStartDate {
            queryItems.append(URLQueryItem(name: "maxStartDate", value: isoFormatter.string(from: maxStartDate)))
        }
        if let value = filters.isAiring {
            queryItems.append(URLQueryItem(name: "isAiring", value: value ? "true" : "false"))
        }
        if let value = filters.hasAired {
            queryItems.append(URLQueryItem(name: "hasAired", value: value ? "true" : "false"))
        }
        if let value = filters.isMovie {
            queryItems.append(URLQueryItem(name: "isMovie", value: value ? "true" : "false"))
        }
        if let value = filters.isSeries {
            queryItems.append(URLQueryItem(name: "isSeries", value: value ? "true" : "false"))
        }
        if let value = filters.isNews {
            queryItems.append(URLQueryItem(name: "isNews", value: value ? "true" : "false"))
        }
        if let value = filters.isKids {
            queryItems.append(URLQueryItem(name: "isKids", value: value ? "true" : "false"))
        }
        if let value = filters.isSports {
            queryItems.append(URLQueryItem(name: "isSports", value: value ? "true" : "false"))
        }
        if let genres = filters.genres, !genres.isEmpty {
            queryItems.append(URLQueryItem(name: "genres", value: genres.joined(separator: "|")))
        }
        if let sortBy = filters.sortBy, !sortBy.isEmpty {
            queryItems.append(URLQueryItem(name: "sortBy", value: sortBy.joined(separator: ",")))
        } else {
            queryItems.append(URLQueryItem(name: "sortBy", value: "StartDate"))
        }
        if let sortOrder = filters.sortOrder {
            queryItems.append(URLQueryItem(name: "sortOrder", value: sortOrder))
        } else {
            queryItems.append(URLQueryItem(name: "sortOrder", value: "Ascending"))
        }
        queryItems.append(URLQueryItem(name: "enableImages", value: "true"))
        queryItems.append(URLQueryItem(name: "enableImageTypes", value: "Primary,Thumb,Backdrop"))
        queryItems.append(URLQueryItem(name: "fields", value: "Overview,Genres"))
        queryItems.append(URLQueryItem(name: "enableTotalRecordCount", value: "false"))
        if let limit = filters.limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        } else {
            queryItems.append(URLQueryItem(name: "limit", value: "500"))
        }
        let request = try buildRequest(path: "/LiveTv/Programs", queryItems: queryItems)
        let result = try await send(request, as: LiveTvProgramQueryResult.self)
        return result.items
    }

    public func liveTvRecommendedPrograms(
        filters: LiveTvProgramFilters
    ) async throws -> [LiveTvProgram] {
        var queryItems: [URLQueryItem] = []
        if let value = filters.isAiring {
            queryItems.append(URLQueryItem(name: "isAiring", value: value ? "true" : "false"))
        }
        if let value = filters.hasAired {
            queryItems.append(URLQueryItem(name: "hasAired", value: value ? "true" : "false"))
        }
        if let value = filters.isMovie {
            queryItems.append(URLQueryItem(name: "isMovie", value: value ? "true" : "false"))
        }
        if let value = filters.isSeries {
            queryItems.append(URLQueryItem(name: "isSeries", value: value ? "true" : "false"))
        }
        if let value = filters.isNews {
            queryItems.append(URLQueryItem(name: "isNews", value: value ? "true" : "false"))
        }
        if let value = filters.isKids {
            queryItems.append(URLQueryItem(name: "isKids", value: value ? "true" : "false"))
        }
        if let value = filters.isSports {
            queryItems.append(URLQueryItem(name: "isSports", value: value ? "true" : "false"))
        }
        if let genres = filters.genres, !genres.isEmpty {
            queryItems.append(URLQueryItem(name: "genres", value: genres.joined(separator: "|")))
        }
        if let limit = filters.limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        } else {
            queryItems.append(URLQueryItem(name: "limit", value: "30"))
        }
        queryItems.append(URLQueryItem(name: "enableImages", value: "true"))
        queryItems.append(URLQueryItem(name: "enableImageTypes", value: "Primary,Thumb,Backdrop"))
        queryItems.append(URLQueryItem(name: "fields", value: "Overview,Genres"))
        queryItems.append(URLQueryItem(name: "enableTotalRecordCount", value: "false"))
        let request = try buildRequest(path: "/LiveTv/Programs/Recommended", queryItems: queryItems)
        let result = try await send(request, as: LiveTvProgramQueryResult.self)
        return result.items
    }

    public func liveTvProgram(programId: String) async throws -> LiveTvProgram {
        let request = try buildRequest(path: "/LiveTv/Programs/\(programId)")
        return try await send(request, as: LiveTvProgram.self)
    }

    // MARK: - Recordings

    public func liveTvRecordings(
        isInProgress: Bool?,
        seriesTimerId: String?,
        limit: Int?
    ) async throws -> [BaseItemDto] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "enableImages", value: "true"),
            URLQueryItem(name: "enableImageTypes", value: "Primary,Thumb,Backdrop"),
            URLQueryItem(name: "enableTotalRecordCount", value: "false"),
            URLQueryItem(name: "fields", value: "Overview,Genres,ChannelInfo"),
        ]
        if let isInProgress {
            queryItems.append(URLQueryItem(name: "isInProgress", value: isInProgress ? "true" : "false"))
        }
        if let seriesTimerId {
            queryItems.append(URLQueryItem(name: "seriesTimerId", value: seriesTimerId))
        }
        if let limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        let request = try buildRequest(path: "/LiveTv/Recordings", queryItems: queryItems)
        let result = try await send(request, as: BaseItemDtoQueryResult.self)
        return result.items
    }

    public func deleteLiveTvRecording(recordingId: String) async throws {
        let request = try buildRequest(path: "/LiveTv/Recordings/\(recordingId)", method: "DELETE")
        try await sendIgnoringResponse(request)
    }

    // MARK: - Timers

    public func liveTvTimers() async throws -> [TimerInfoDto] {
        let request = try buildRequest(path: "/LiveTv/Timers")
        let result = try await send(request, as: TimerInfoDtoQueryResult.self)
        return result.items
    }

    public func liveTvSeriesTimers() async throws -> [SeriesTimerInfoDto] {
        let request = try buildRequest(path: "/LiveTv/SeriesTimers")
        let result = try await send(request, as: SeriesTimerInfoDtoQueryResult.self)
        return result.items
    }

    public func liveTvTimerDefaults(programId: String?) async throws -> Data {
        var queryItems: [URLQueryItem] = []
        if let programId {
            queryItems.append(URLQueryItem(name: "programId", value: programId))
        }
        let request = try buildRequest(
            path: "/LiveTv/Timers/Defaults",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        return try await sendRaw(request)
    }

    public func createLiveTvTimer(body: Data) async throws {
        let request = try buildRequest(path: "/LiveTv/Timers", method: "POST", body: body)
        try await sendIgnoringResponse(request)
    }

    public func createLiveTvSeriesTimer(body: Data) async throws {
        let request = try buildRequest(path: "/LiveTv/SeriesTimers", method: "POST", body: body)
        try await sendIgnoringResponse(request)
    }

    public func cancelLiveTvTimer(timerId: String) async throws {
        let request = try buildRequest(path: "/LiveTv/Timers/\(timerId)", method: "DELETE")
        try await sendIgnoringResponse(request)
    }

    public func cancelLiveTvSeriesTimer(timerId: String) async throws {
        let request = try buildRequest(path: "/LiveTv/SeriesTimers/\(timerId)", method: "DELETE")
        try await sendIgnoringResponse(request)
    }

    // MARK: - Favorites

    public func setFavorite(itemId: String, isFavorite: Bool) async throws {
        let method = isFavorite ? "POST" : "DELETE"
        let request = try buildRequest(path: "/UserFavoriteItems/\(itemId)", method: method)
        try await sendIgnoringResponse(request)
    }

    // MARK: - Streams

    public func liveTvOpenStream(channelId: String) async throws -> LiveStreamPlayback {
        try await liveTvOpenStream(channelId: channelId, forceTranscoding: false)
    }

    /// Open a live stream. When `forceTranscoding == true`, sends
    /// `enableDirectPlay=false` so the server won't hand back a progressive
    /// `/Videos/{id}/stream.{container}` URL — used by the player as a
    /// DirectPlay-fallback retry when AVPlayer can't consume the direct stream
    /// for live media.
    public func liveTvOpenStream(
        channelId: String,
        forceTranscoding: Bool
    ) async throws -> LiveStreamPlayback {
        JellytvLog.liveTV.info("liveTvOpenStream(channelId: \(channelId, privacy: .public), forceTranscoding: \(forceTranscoding))")
        guard let token = accessToken else {
            JellytvLog.liveTV.error("liveTvOpenStream: no access token — not signed in")
            throw JellyfinError.unauthenticated
        }
        guard let serverURL else {
            JellytvLog.liveTV.error("liveTvOpenStream: no server URL configured")
            throw JellyfinError.notConfigured
        }
        let userId = try await resolveUserId()

        // PlaybackInfo is the unified stream-open path that Swiftfin and the
        // Jellyfin web client use for both VOD and live TV. Setting
        // autoOpenLiveStream=true on a TvChannel item makes the server open
        // the live stream as part of the call.
        let body = try encoder.encode(PlaybackInfoBody(deviceProfile: .liveTvDefault))
        let queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "autoOpenLiveStream", value: "true"),
            URLQueryItem(name: "maxStreamingBitrate", value: "120000000"),
            URLQueryItem(name: "startTimeTicks", value: "0"),
            URLQueryItem(name: "enableDirectPlay", value: forceTranscoding ? "false" : "true"),
            URLQueryItem(name: "enableDirectStream", value: forceTranscoding ? "false" : "true"),
            URLQueryItem(name: "enableTranscoding", value: "true"),
            URLQueryItem(name: "allowVideoStreamCopy", value: "true"),
            URLQueryItem(name: "allowAudioStreamCopy", value: "true"),
        ]
        let request = try buildRequest(
            path: "/Items/\(channelId)/PlaybackInfo",
            method: "POST",
            queryItems: queryItems,
            body: body
        )
        let response = try await send(request, as: LiveStreamResponse.self)
        guard let source = response.primary else {
            JellytvLog.liveTV.error("liveTvOpenStream: response had neither MediaSource nor MediaSources[0]")
            throw JellyfinError.decoding(
                DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "LiveStreamResponse missing MediaSource")
                )
            )
        }
        JellytvLog.liveTV.debug("liveTvOpenStream: source id=\(source.id ?? "?", privacy: .public) container=\(source.container ?? "?", privacy: .public) transcoding=\(source.transcodingUrl ?? "<none>", privacy: .public) liveStreamId=\(source.liveStreamId ?? "<none>", privacy: .public)")
        let playbackURL = try makePlaybackURL(source: source, serverURL: serverURL, token: token)
        JellytvLog.liveTV.info("liveTvOpenStream: resolved playback URL \(playbackURL.absoluteString, privacy: .public)")
        return LiveStreamPlayback(playbackURL: playbackURL, liveStreamId: source.liveStreamId)
    }

    public func liveTvCloseStream(liveStreamId: String) async throws {
        JellytvLog.liveTV.info("liveTvCloseStream(liveStreamId: \(liveStreamId, privacy: .public))")
        let request = try buildRequest(
            path: "/LiveStreams/Close",
            method: "POST",
            queryItems: [URLQueryItem(name: "liveStreamId", value: liveStreamId)]
        )
        try await sendIgnoringResponse(request)
    }

    /// Build a playback URL from a `MediaSourceInfo`. Prefers the server-supplied
    /// `transcodingUrl` (which already contains baked auth params); falls back to
    /// constructing a direct-stream URL via `URLComponents`. NEVER uses
    /// `appendingPathComponent` with a query-bearing string — that percent-encodes
    /// the `?` and breaks the URL.
    ///
    /// For live streams, the device profile in `liveTvOpenStream` requests an HLS
    /// transcode (`container=ts`, `protocol=hls`, `breakOnNonKeyFrames=true`), so
    /// Jellyfin returns a `transcodingUrl` that already points at the
    /// `/videos/{id}/master.m3u8` endpoint with the right HLS query params baked
    /// in. We resolve that relative URL against `serverURL` and play it as-is.
    /// The only client-side fix-up is stripping empty-name query items the server
    /// occasionally emits (`?&...`) which break some HLS clients' query parsing.
    private func makePlaybackURL(
        source: MediaSourceInfo,
        serverURL: URL,
        token: String
    ) throws -> URL {
        if let transcodingUrl = source.transcodingUrl {
            // Resolve the relative URL against the server. Do NOT append api_key —
            // Jellyfin bakes auth into transcodingUrl when it constructs it.
            guard let resolved = URL(string: transcodingUrl, relativeTo: serverURL)?.absoluteURL else {
                throw JellyfinError.decoding(
                    DecodingError.dataCorrupted(
                        .init(codingPath: [], debugDescription: "Invalid transcodingUrl: \(transcodingUrl)")
                    )
                )
            }
            // For live streams, strip empty-name query items — Jellyfin's
            // TranscodingUrl sometimes starts with `?&` which leaves a stray
            // empty parameter that some HLS clients reject. The path itself is
            // honored verbatim (no rewrites — the device profile drove the server
            // to emit a real master.m3u8 URL).
            if source.liveStreamId != nil,
               var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) {
                if let items = components.queryItems {
                    let cleaned = items.filter { !$0.name.isEmpty }
                    components.queryItems = cleaned.isEmpty ? nil : cleaned
                }
                if let cleanedURL = components.url {
                    return cleanedURL
                }
            }
            return resolved
        }

        guard let id = source.id, let container = source.container else {
            throw JellyfinError.decoding(
                DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "MediaSource missing Id or Container for direct-stream fallback")
                )
            )
        }

        var components = URLComponents()
        components.scheme = serverURL.scheme
        components.host = serverURL.host
        components.port = serverURL.port
        components.path = "/Videos/\(id)/stream.\(container)"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "MediaSourceId", value: id),
            URLQueryItem(name: "static", value: "true"),
            URLQueryItem(name: "api_key", value: token),
        ]
        if let liveStreamId = source.liveStreamId {
            items.append(URLQueryItem(name: "LiveStreamId", value: liveStreamId))
        }
        components.queryItems = items
        guard let url = components.url else {
            throw JellyfinError.invalidServerURL
        }
        return url
    }

    // MARK: - Private: Authorization header

    private func authorizationHeaderValue() -> String {
        var parts = [
            "Client=\"\(percentEncode(clientName))\"",
            "Device=\"\(percentEncode(deviceName))\"",
            "DeviceId=\"\(percentEncode(deviceId))\"",
            "Version=\"\(percentEncode(clientVersion))\"",
        ]
        if let token = accessToken {
            parts.append("Token=\"\(percentEncode(token))\"")
        }
        return "MediaBrowser " + parts.joined(separator: ", ")
    }

    private func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    // MARK: - Private: Request builder

    private func buildRequest(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) throws -> URLRequest {
        guard let serverURL else { throw JellyfinError.notConfigured }
        var components = URLComponents(
            url: serverURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if let queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else { throw JellyfinError.invalidServerURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(authorizationHeaderValue(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    // MARK: - Private: Send helpers

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type = T.self) async throws -> T {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? "<no-url>"
        JellytvLog.api.debug("→ \(method, privacy: .public) \(path, privacy: .public)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            JellytvLog.api.error("✗ \(method, privacy: .public) \(path, privacy: .public) network error: \(urlError.localizedDescription, privacy: .public) (code: \(urlError.code.rawValue))")
            throw JellyfinError.network(urlError)
        } catch {
            JellytvLog.api.error("✗ \(method, privacy: .public) \(path, privacy: .public) unknown error: \(String(describing: error), privacy: .public)")
            throw JellyfinError.network(URLError(.unknown))
        }

        guard let http = response as? HTTPURLResponse else {
            JellytvLog.api.error("✗ \(method, privacy: .public) \(path, privacy: .public) bad server response (not HTTP)")
            throw JellyfinError.network(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            JellytvLog.api.debug("← \(http.statusCode) \(method, privacy: .public) \(path, privacy: .public) (\(data.count) bytes)")
            do {
                return try decoder.decode(T.self, from: data)
            } catch let decodingError as DecodingError {
                let bodySnippet = String(data: data.prefix(512), encoding: .utf8) ?? "<binary>"
                JellytvLog.api.error("✗ \(method, privacy: .public) \(path, privacy: .public) decode failed: \(String(describing: decodingError), privacy: .public)\nbody: \(bodySnippet, privacy: .public)")
                throw JellyfinError.decoding(decodingError)
            }
        case 401:
            JellytvLog.api.error("✗ \(method, privacy: .public) \(path, privacy: .public) 401 unauthenticated")
            throw JellyfinError.unauthenticated
        default:
            let problem = try? decoder.decode(ProblemDetails.self, from: data)
            let bodySnippet = String(data: data.prefix(512), encoding: .utf8) ?? "<binary>"
            JellytvLog.api.error("✗ \(method, privacy: .public) \(path, privacy: .public) HTTP \(http.statusCode) \(problem?.title ?? "", privacy: .public) — \(problem?.detail ?? bodySnippet, privacy: .public)")
            throw JellyfinError.http(status: http.statusCode, problem: problem)
        }
    }

    /// Send a request and return the raw response body. Used for endpoints
    /// (e.g. `/LiveTv/Timers/Defaults`) where the response is an arbitrary
    /// JSON document that callers will round-trip back to a sibling endpoint.
    private func sendRaw(_ request: URLRequest) async throws -> Data {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? "<no-url>"
        JellytvLog.api.debug("→ \(method, privacy: .public) \(path, privacy: .public)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw JellyfinError.network(urlError)
        } catch {
            throw JellyfinError.network(URLError(.unknown))
        }

        guard let http = response as? HTTPURLResponse else {
            throw JellyfinError.network(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            throw JellyfinError.unauthenticated
        default:
            let problem = try? decoder.decode(ProblemDetails.self, from: data)
            throw JellyfinError.http(status: http.statusCode, problem: problem)
        }
    }

    private func sendIgnoringResponse(_ request: URLRequest) async throws {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw JellyfinError.network(urlError)
        } catch {
            throw JellyfinError.network(URLError(.unknown))
        }

        guard let http = response as? HTTPURLResponse else {
            throw JellyfinError.network(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            return
        case 401:
            throw JellyfinError.unauthenticated
        default:
            let problem = try? decoder.decode(ProblemDetails.self, from: data)
            throw JellyfinError.http(status: http.statusCode, problem: problem)
        }
    }
}
