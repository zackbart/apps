import Testing
import Foundation
@testable import LiveTV
@testable import JellyfinAPI

@Suite("GuideModel")
@MainActor
struct GuideModelTests {

    /// Stable "now" used by every test so date math is deterministic.
    /// 2026-04-07 19:00:00 UTC
    private var fixedNow: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 7
        components.hour = 19
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func makeChannel(id: String, name: String) -> LiveTvChannel {
        LiveTvChannel(id: id, name: name)
    }

    private func makeProgram(
        id: String,
        channelId: String,
        startOffset: TimeInterval,
        durationMinutes: Double,
        from now: Date
    ) -> LiveTvProgram {
        let start = now.addingTimeInterval(startOffset)
        let end = start.addingTimeInterval(durationMinutes * 60)
        return LiveTvProgram(
            id: id,
            name: "Program \(id)",
            channelId: channelId,
            startDate: start,
            endDate: end
        )
    }

    @Test func loadSuccess() async throws {
        let now = fixedNow
        let mock = FakeJellyfinClient()
        mock.liveTvChannelsResult = .success([
            makeChannel(id: "ch-1", name: "MLB Network"),
            makeChannel(id: "ch-2", name: "ESPN"),
        ])
        mock.liveTvProgramsResult = .success([
            // ch-1: program starting at now, 60 min long
            makeProgram(id: "p1", channelId: "ch-1", startOffset: 0, durationMinutes: 60, from: now),
            // ch-1: program starting in 60 min, 30 min long
            makeProgram(id: "p2", channelId: "ch-1", startOffset: 60 * 60, durationMinutes: 30, from: now),
            // ch-2: program starting at now, 30 min long
            makeProgram(id: "p3", channelId: "ch-2", startOffset: 0, durationMinutes: 30, from: now),
        ])

        let store = EPGStore(client: mock, now: { now })
        let model = GuideModel(client: mock, store: store, now: { now })
        await model.load()

        guard case .loaded(let content) = model.state else {
            Issue.record("Expected .loaded, got \(model.state)")
            return
        }
        #expect(content.channels.count == 2)
        #expect(content.windowStart == now)
        #expect(content.windowEnd == now.addingTimeInterval(GuideLayout.futureWindowSeconds))
        #expect(content.programs(for: "ch-1").count == 2)
        #expect(content.programs(for: "ch-2").count == 1)
        // First channel's programs are sorted by startDate ascending
        #expect(content.programs(for: "ch-1").map(\.id) == ["p1", "p2"])
        // Verify the model widened minStartDate by pastWindowSeconds when calling the API
        #expect(mock.lastMinStartDate == now.addingTimeInterval(-GuideLayout.pastWindowSeconds))
        #expect(mock.lastMaxStartDate == now.addingTimeInterval(GuideLayout.futureWindowSeconds))
        #expect(mock.lastChannelIds == ["ch-1", "ch-2"])
    }

    @Test func loadEmptyChannelsSkipsProgramsCall() async throws {
        let now = fixedNow
        let mock = FakeJellyfinClient()
        mock.liveTvChannelsResult = .success([])
        // If liveTvPrograms is called when channels is empty, the test would fail
        // because lastChannelIds gets set.
        mock.liveTvProgramsResult = .success([
            makeProgram(id: "should-not-appear", channelId: "ch-1", startOffset: 0, durationMinutes: 30, from: now)
        ])

        let store = EPGStore(client: mock, now: { now })
        let model = GuideModel(client: mock, store: store, now: { now })
        await model.load()

        guard case .loaded(let content) = model.state else {
            Issue.record("Expected .loaded, got \(model.state)")
            return
        }
        #expect(content.isEmpty)
        #expect(content.channels.isEmpty)
        #expect(mock.lastChannelIds == nil)
    }

    @Test func networkErrorMapsToFailed() async throws {
        let now = fixedNow
        let mock = FakeJellyfinClient()
        mock.liveTvChannelsResult = .failure(JellyfinError.network(URLError(.notConnectedToInternet)))

        let store = EPGStore(client: mock, now: { now })
        let model = GuideModel(client: mock, store: store, now: { now })
        await model.load()

        guard case .failed(let message) = model.state else {
            Issue.record("Expected .failed, got \(model.state)")
            return
        }
        #expect(message.contains("Couldn't reach"))
    }

    @Test func unauthorizedMapsToFailed() async throws {
        let now = fixedNow
        let mock = FakeJellyfinClient()
        mock.liveTvChannelsResult = .failure(JellyfinError.unauthenticated)

        let store = EPGStore(client: mock, now: { now })
        let model = GuideModel(client: mock, store: store, now: { now })
        await model.load()

        guard case .failed(let message) = model.state else {
            Issue.record("Expected .failed, got \(model.state)")
            return
        }
        #expect(message.contains("Session"))
    }

    @Test func notConfiguredMapsToFailed() async throws {
        let now = fixedNow
        let mock = FakeJellyfinClient()
        mock.currentServerURL_ = nil

        let store = EPGStore(client: mock, now: { now })
        let model = GuideModel(client: mock, store: store, now: { now })
        await model.load()

        guard case .failed(let message) = model.state else {
            Issue.record("Expected .failed, got \(model.state)")
            return
        }
        #expect(message.contains("Not signed in"))
    }

    @Test func programsEndingBeforeWindowStartAreDropped() async throws {
        let now = fixedNow
        let mock = FakeJellyfinClient()
        mock.liveTvChannelsResult = .success([makeChannel(id: "ch-1", name: "MLB")])
        mock.liveTvProgramsResult = .success([
            // Already ended 30 min ago: should be dropped
            makeProgram(id: "ended", channelId: "ch-1", startOffset: -2 * 3600, durationMinutes: 90, from: now),
            // In progress (started 30 min ago, ends in 30 min): should be kept
            makeProgram(id: "live", channelId: "ch-1", startOffset: -30 * 60, durationMinutes: 60, from: now),
            // Future: should be kept
            makeProgram(id: "future", channelId: "ch-1", startOffset: 60 * 60, durationMinutes: 30, from: now),
        ])

        let store = EPGStore(client: mock, now: { now })
        let model = GuideModel(client: mock, store: store, now: { now })
        await model.load()

        guard case .loaded(let content) = model.state else {
            Issue.record("Expected .loaded, got \(model.state)")
            return
        }
        let ids = content.programs(for: "ch-1").map(\.id)
        #expect(ids == ["live", "future"])
    }

    @Test func applyFilterUsesFilteredChannelEndpoint() async throws {
        let now = fixedNow
        let mock = FakeJellyfinClient()
        // Default channels endpoint returns one set; the filtered version
        // returns a different set so we can prove the model called the right
        // method when a non-`.all` filter is applied.
        mock.liveTvChannelsResult = .success([makeChannel(id: "default", name: "Default")])
        mock.liveTvFilteredChannelsResult = .success([makeChannel(id: "sports", name: "ESPN")])
        mock.liveTvProgramsResult = .success([])

        let store = EPGStore(client: mock, now: { now })
        let model = GuideModel(client: mock, store: store, now: { now })
        await model.applyFilter(.sports)

        guard case .loaded(let content) = model.state else {
            Issue.record("Expected .loaded, got \(model.state)")
            return
        }
        #expect(content.channels.map(\.id) == ["sports"])
        #expect(model.categoryFilter == .sports)
        #expect(mock.lastChannelFilters?.isSports == true)
        #expect(mock.lastAddCurrentProgram == false)
    }

    @Test func programsForUnknownChannelsAreIgnored() async throws {
        let now = fixedNow
        let mock = FakeJellyfinClient()
        mock.liveTvChannelsResult = .success([makeChannel(id: "ch-1", name: "MLB")])
        mock.liveTvProgramsResult = .success([
            makeProgram(id: "ok", channelId: "ch-1", startOffset: 0, durationMinutes: 30, from: now),
            makeProgram(id: "orphan", channelId: "ch-99", startOffset: 0, durationMinutes: 30, from: now),
        ])

        let store = EPGStore(client: mock, now: { now })
        let model = GuideModel(client: mock, store: store, now: { now })
        await model.load()

        guard case .loaded(let content) = model.state else {
            Issue.record("Expected .loaded, got \(model.state)")
            return
        }
        #expect(content.programsByChannel.keys.sorted() == ["ch-1"])
        #expect(content.programs(for: "ch-1").count == 1)
    }
}
