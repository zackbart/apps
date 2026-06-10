import Testing
import Foundation
@testable import LiveTV
@testable import JellyfinAPI

/// Sendable mutable clock for injecting into EPGStore in tests.
final class TestClock: @unchecked Sendable {
    private var _now: Date
    private let lock = NSLock()

    init(_ initial: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        _now = initial
    }

    var now: Date {
        lock.withLock { _now }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { _now = _now.addingTimeInterval(interval) }
    }
}

@Suite("EPGStore")
@MainActor
struct EPGStoreTests {

    private func ch(_ id: String) -> LiveTvChannel {
        LiveTvChannel(id: id, name: "Channel \(id)")
    }

    // MARK: - Coalescing

    @Test func concurrentUnfilteredRequestsShareOneClientCall() async throws {
        let mock = FakeJellyfinClient()
        mock.liveTvChannelsResult = .success([ch("a"), ch("b")])
        let store = EPGStore(client: mock)

        // Fire 5 concurrent requests for the same key.
        async let r1 = store.channels()
        async let r2 = store.channels()
        async let r3 = store.channels()
        async let r4 = store.channels()
        async let r5 = store.channels()

        let results = try await [r1, r2, r3, r4, r5]
        #expect(results.count == 5)
        #expect(results.allSatisfy { $0.count == 2 })
        // Only one actual client call despite 5 concurrent callers.
        #expect(mock.liveTvChannelsCallCount == 1)
    }

    @Test func concurrentFilteredRequestsSameKeyShareOneClientCall() async throws {
        let mock = FakeJellyfinClient()
        mock.liveTvFilteredChannelsResult = .success([ch("x")])
        let store = EPGStore(client: mock)

        let filters = LiveTvChannelFilters(isSports: true, isAiringNow: true, limit: 24)
        async let r1 = store.channels(filters: filters, addCurrentProgram: true)
        async let r2 = store.channels(filters: filters, addCurrentProgram: true)
        async let r3 = store.channels(filters: filters, addCurrentProgram: true)

        let results = try await [r1, r2, r3]
        #expect(results.count == 3)
        #expect(results.allSatisfy { $0.count == 1 })
        // Only one actual client call.
        #expect(mock.liveTvChannelsFilteredCallCount == 1)
    }

    // MARK: - TTL

    @Test func secondRequestWithinTTLHitsCache() async throws {
        let clock = TestClock()
        let mock = FakeJellyfinClient()
        mock.liveTvChannelsResult = .success([ch("a")])
        let store = EPGStore(client: mock, now: { clock.now })

        // First fetch.
        _ = try await store.channels()
        #expect(mock.liveTvChannelsCallCount == 1)

        // Advance time by 4 minutes (within 5-minute TTL).
        clock.advance(by: 4 * 60)

        // Second fetch — should hit cache.
        _ = try await store.channels()
        #expect(mock.liveTvChannelsCallCount == 1, "Expected cache hit; count should remain 1")
    }

    @Test func requestAfterTTLRefetches() async throws {
        let clock = TestClock()
        let mock = FakeJellyfinClient()
        mock.liveTvChannelsResult = .success([ch("a")])
        let store = EPGStore(client: mock, now: { clock.now })

        // First fetch.
        _ = try await store.channels()
        #expect(mock.liveTvChannelsCallCount == 1)

        // Advance time past TTL (5 min + 1 sec).
        clock.advance(by: 5 * 60 + 1)

        // Second fetch — TTL expired, should call client again.
        _ = try await store.channels()
        #expect(mock.liveTvChannelsCallCount == 2, "Expected TTL expiry refetch; count should be 2")
    }

    // MARK: - Per-key isolation

    @Test func differentFilterKeysProduceSeparateFetches() async throws {
        let mock = FakeJellyfinClient()
        mock.liveTvFilteredChannelsResult = .success([ch("filtered")])
        let store = EPGStore(client: mock)

        let sportsFilters = LiveTvChannelFilters(isSports: true, isAiringNow: true, limit: 24)
        let newsFilters = LiveTvChannelFilters(isNews: true, isAiringNow: true, limit: 24)

        _ = try await store.channels(filters: sportsFilters, addCurrentProgram: true)
        _ = try await store.channels(filters: newsFilters, addCurrentProgram: true)

        // Two different keys → two separate client calls.
        #expect(mock.liveTvChannelsFilteredCallCount == 2)
    }

    @Test func unfilteredAndFilteredKeysAreIsolated() async throws {
        let mock = FakeJellyfinClient()
        mock.liveTvChannelsResult = .success([ch("all")])
        mock.liveTvFilteredChannelsResult = .success([ch("filtered")])
        let store = EPGStore(client: mock)

        let unfiltered = try await store.channels()
        let filtered = try await store.channels(
            filters: LiveTvChannelFilters(isMovie: true),
            addCurrentProgram: false
        )

        #expect(unfiltered.map(\.id) == ["all"])
        #expect(filtered.map(\.id) == ["filtered"])
        #expect(mock.liveTvChannelsCallCount == 1)
        #expect(mock.liveTvChannelsFilteredCallCount == 1)
    }

    // MARK: - Dominant-color pre-warm ordering

    @Test func channelsForColorPrewarmFavoritesComeFirst() {
        let fav = LiveTvChannel(
            id: "fav1", name: "Fav 1", number: "10",
            userData: UserItemDataDto(isFavorite: true)
        )
        let reg1 = LiveTvChannel(id: "reg1", name: "Reg 1", number: "20")
        let reg2 = LiveTvChannel(id: "reg2", name: "Reg 2", number: "30")
        // Input is already sorted by channel number; favorite is channel 10.
        let ordered = EPGStore.channelsForColorPrewarm([fav, reg1, reg2])
        #expect(ordered.map(\.id) == ["fav1", "reg1", "reg2"])
    }

    @Test func channelsForColorPrewarmFavoritesLeadAmongMixed() {
        let fav1 = LiveTvChannel(
            id: "fav1", name: "Fav 1", number: "30",
            userData: UserItemDataDto(isFavorite: true)
        )
        let fav2 = LiveTvChannel(
            id: "fav2", name: "Fav 2", number: "50",
            userData: UserItemDataDto(isFavorite: true)
        )
        let reg1 = LiveTvChannel(id: "reg1", name: "Reg 1", number: "10")
        let reg2 = LiveTvChannel(id: "reg2", name: "Reg 2", number: "20")
        let reg3 = LiveTvChannel(id: "reg3", name: "Reg 3", number: "40")
        // Sorted input: reg1, reg2, fav1, reg3, fav2
        let ordered = EPGStore.channelsForColorPrewarm([reg1, reg2, fav1, reg3, fav2])
        // Favorites come first (in their original order), then non-favorites.
        #expect(ordered.map(\.id) == ["fav1", "fav2", "reg1", "reg2", "reg3"])
    }

    @Test func channelsForColorPrewarmCapsAtLimit() {
        // Build 60 channels, first 5 as favorites.
        let channels: [LiveTvChannel] = (1...60).map { i in
            LiveTvChannel(
                id: "ch\(i)", name: "Channel \(i)", number: String(i),
                userData: i <= 5 ? UserItemDataDto(isFavorite: true) : nil
            )
        }
        let ordered = EPGStore.channelsForColorPrewarm(channels)
        #expect(ordered.count == EPGStore.dominantColorPrewarmLimit)
        // First 5 should be the favorites.
        #expect(ordered.prefix(5).map(\.id) == ["ch1", "ch2", "ch3", "ch4", "ch5"])
    }

    // MARK: - unfilteredChannels sorted property

    @Test func unfilteredChannelsIsSortedByChannelNumber() async throws {
        let mock = FakeJellyfinClient()
        mock.liveTvChannelsResult = .success([
            LiveTvChannel(id: "c", name: "C", number: "103"),
            LiveTvChannel(id: "a", name: "A", number: "101"),
            LiveTvChannel(id: "b", name: "B", number: "102"),
        ])
        let store = EPGStore(client: mock)

        _ = try await store.channels()
        #expect(store.unfilteredChannels.map(\.id) == ["a", "b", "c"])
    }
}
