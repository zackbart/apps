import Foundation
import Observation
import JellyfinAPI
import DesignSystem

/// Cache key for a `/LiveTv/Channels` query. Captures all parameters that
/// affect the server response so different queries never collide.
public struct ChannelQueryKey: Hashable, Sendable {
    /// true = unfiltered `liveTvChannels()` overload; false = filtered overload
    public let isUnfiltered: Bool

    // Filtered-overload parameters (nil when isUnfiltered == true)
    public let isMovie: Bool?
    public let isSeries: Bool?
    public let isNews: Bool?
    public let isKids: Bool?
    public let isSports: Bool?
    public let isFavorite: Bool?
    public let isAiringNow: Bool?
    public let sortBy: String?
    public let sortOrder: String?
    public let startIndex: Int?
    public let limit: Int?
    public let addCurrentProgram: Bool?

    /// Key for the unfiltered `liveTvChannels()` call.
    public static let unfiltered = ChannelQueryKey(
        isUnfiltered: true,
        isMovie: nil, isSeries: nil, isNews: nil, isKids: nil, isSports: nil,
        isFavorite: nil, isAiringNow: nil, sortBy: nil, sortOrder: nil,
        startIndex: nil, limit: nil, addCurrentProgram: nil
    )

    /// Key for a filtered `liveTvChannels(filters:addCurrentProgram:)` call.
    public static func filtered(_ filters: LiveTvChannelFilters, addCurrentProgram: Bool) -> ChannelQueryKey {
        ChannelQueryKey(
            isUnfiltered: false,
            isMovie: filters.isMovie,
            isSeries: filters.isSeries,
            isNews: filters.isNews,
            isKids: filters.isKids,
            isSports: filters.isSports,
            isFavorite: filters.isFavorite,
            isAiringNow: filters.isAiringNow,
            sortBy: filters.sortBy,
            sortOrder: filters.sortOrder,
            startIndex: filters.startIndex,
            limit: filters.limit,
            addCurrentProgram: addCurrentProgram
        )
    }
}

private struct CacheEntry {
    let channels: [LiveTvChannel]
    let fetchedAt: Date
}

/// Request-coalescing, TTL-keyed cache for `/LiveTv/Channels` calls.
///
/// Multiple concurrent callers asking for the same key share a single
/// in-flight `Task`. After the task completes the result is stored and
/// served from cache for 5 minutes. After TTL expiry the next caller
/// triggers a fresh fetch.
///
/// Owns a sorted, deduplicated copy of the unfiltered channel list via
/// `unfilteredChannels` — suitable as the player zap list.
@MainActor
@Observable
public final class EPGStore {

    // MARK: - Public observable state

    /// Sorted unfiltered channel list (post-first-fetch). Empty before first load.
    public private(set) var unfilteredChannels: [LiveTvChannel] = []
    /// True while the very first unfiltered fetch is in progress.
    public private(set) var isLoadingUnfiltered: Bool = false
    /// Last error from the unfiltered fetch (for root-view error presentation).
    public private(set) var lastError: String?

    // MARK: - Configuration

    /// Injectable clock — replace in tests to fast-forward time.
    public var now: @Sendable () -> Date

    // MARK: - Private state

    private let client: any JellyfinClientAPI
    private var cache: [ChannelQueryKey: CacheEntry] = [:]
    private var inFlight: [ChannelQueryKey: Task<[LiveTvChannel], Error>] = [:]

    private static let ttl: TimeInterval = 5 * 60

    // MARK: - Init

    public init(
        client: any JellyfinClientAPI,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.now = now
    }

    // MARK: - Public API — mirrors the two client overloads exactly

    /// Fetch all channels (unfiltered). Mirrors `client.liveTvChannels()`.
    public func channels() async throws -> [LiveTvChannel] {
        try await fetch(key: .unfiltered)
    }

    /// Fetch channels with filters. Mirrors `client.liveTvChannels(filters:addCurrentProgram:)`.
    public func channels(
        filters: LiveTvChannelFilters,
        addCurrentProgram: Bool
    ) async throws -> [LiveTvChannel] {
        try await fetch(key: .filtered(filters, addCurrentProgram: addCurrentProgram))
    }

    // MARK: - Pre-warm

    /// Pre-warm the unfiltered channel list, updating `unfilteredChannels` when done.
    /// Safe to call multiple times — coalesced by the normal in-flight dedup.
    public func prewarm() async {
        guard !isLoadingUnfiltered else { return }
        isLoadingUnfiltered = true
        do {
            let result = try await channels()
            unfilteredChannels = ChannelOrdering.sortedByChannelNumber(result)
            lastError = nil
        } catch {
            lastError = String(describing: error)
            JellytvLog.liveTV.error("EPGStore.prewarm: \(String(describing: error), privacy: .public)")
        }
        isLoadingUnfiltered = false
    }

    // MARK: - Dominant-color pre-warm

    /// Maximum number of channels to pre-warm dominant colors for.
    static let dominantColorPrewarmLimit = 50

    /// Returns the zap-list channels ordered for dominant-color pre-warming:
    /// favorites first (preserving channel order within each group), then the
    /// rest, capped at `dominantColorPrewarmLimit`.
    static func channelsForColorPrewarm(_ channels: [LiveTvChannel]) -> [LiveTvChannel] {
        let favorites = channels.filter { $0.userData?.isFavorite == true }
        let rest = channels.filter { $0.userData?.isFavorite != true }
        return Array((favorites + rest).prefix(dominantColorPrewarmLimit))
    }

    /// Fire-and-forget background pre-warm of `ChannelDominantColor` for the
    /// top channels in the zap list. Favorites are processed first; total
    /// capped at `dominantColorPrewarmLimit`. Errors are silently swallowed.
    ///
    /// Must be called after `unfilteredChannels` is populated (i.e. after
    /// `prewarm()` completes) and once `serverURL` is known.
    func prewarmDominantColors(serverURL: URL) {
        let ordered = Self.channelsForColorPrewarm(unfilteredChannels)
        Task(priority: .background) {
            for channel in ordered {
                let url = channel.logoURL(serverURL: serverURL, maxWidth: 256)
                _ = await ChannelDominantColor.shared.extract(logoURL: url)
            }
        }
    }

    // MARK: - Core fetch / coalesce / cache

    private func fetch(key: ChannelQueryKey) async throws -> [LiveTvChannel] {
        // 1. Cache hit within TTL?
        if let entry = cache[key], now().timeIntervalSince(entry.fetchedAt) < Self.ttl {
            return entry.channels
        }

        // 2. Already in flight for this key — await the same task.
        if let existing = inFlight[key] {
            return try await existing.value
        }

        // 3. Kick off a new fetch.
        let task = Task<[LiveTvChannel], Error> { [weak self] in
            guard let self else { throw CancellationError() }
            let result: [LiveTvChannel]
            if key.isUnfiltered {
                result = try await self.client.liveTvChannels()
            } else {
                let filters = LiveTvChannelFilters(
                    isMovie: key.isMovie,
                    isSeries: key.isSeries,
                    isNews: key.isNews,
                    isKids: key.isKids,
                    isSports: key.isSports,
                    isFavorite: key.isFavorite,
                    isAiringNow: key.isAiringNow,
                    sortBy: key.sortBy,
                    sortOrder: key.sortOrder,
                    startIndex: key.startIndex,
                    limit: key.limit
                )
                result = try await self.client.liveTvChannels(
                    filters: filters,
                    addCurrentProgram: key.addCurrentProgram ?? false
                )
            }
            return result
        }

        inFlight[key] = task

        do {
            let channels = try await task.value
            cache[key] = CacheEntry(channels: channels, fetchedAt: now())
            inFlight.removeValue(forKey: key)
            // Keep unfilteredChannels up to date when the unfiltered key is fetched.
            if key.isUnfiltered {
                unfilteredChannels = ChannelOrdering.sortedByChannelNumber(channels)
            }
            return channels
        } catch {
            inFlight.removeValue(forKey: key)
            throw error
        }
    }
}
