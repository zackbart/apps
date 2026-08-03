import Testing
import Foundation
@testable import LiveTV
@testable import JellyfinAPI

@Suite("OnNowModel")
@MainActor
struct OnNowModelTests {

    private func channel(_ id: String, name: String, favorite: Bool = false) -> LiveTvChannel {
        LiveTvChannel(
            id: id,
            name: name,
            userData: UserItemDataDto(isFavorite: favorite),
            currentProgram: LiveTvProgram(id: "p-\(id)", name: "Program \(id)")
        )
    }

    @Test func loadFansOutAndDeduplicates() async throws {
        let mock = FakeJellyfinClient()
        let favorite = channel("fav", name: "Favorite", favorite: true)
        let onNow = channel("on1", name: "On Now")
        let movies = channel("m1", name: "Movies")
        // The favorite channel also appears in On Now — `OnNowModel`
        // should drop the duplicate from `onNow` (and other sub-shelves).
        mock.liveTvFilteredChannelsResult = .success([favorite, onNow])
        mock.liveTvChannelsResult = .success([favorite, onNow, movies])
        mock.liveTvRecommendedResult = .success([
            LiveTvProgram(id: "p1", name: "Up Next 1"),
            LiveTvProgram(id: "p2", name: "Up Next 2"),
        ])
        mock.liveTvRecordingsResult = .success([])

        let store = EPGStore(client: mock)
        let model = OnNowModel(client: mock, store: store)
        await model.load()

        guard case .loaded(let content) = model.state else {
            Issue.record("Expected loaded state, got \(model.state)")
            return
        }
        #expect(content.upNext.count == 2)
        // Favorite channel should be in `favorites`, and *not* duplicated in the
        // other channel shelves (filtered out by id).
        #expect(content.onNow.contains(where: { $0.id == "fav" }) == false)
    }

    @Test func loadWithoutServerURLFailsCleanly() async throws {
        let mock = FakeJellyfinClient()
        mock.currentServerURL_ = nil

        let store = EPGStore(client: mock)
        let model = OnNowModel(client: mock, store: store)
        await model.load()
        guard case .failed(let message) = model.state else {
            Issue.record("Expected failed state, got \(model.state)")
            return
        }
        #expect(message.contains("Not signed in"))
    }
}

@Suite("RecordingsModel")
@MainActor
struct RecordingsModelTests {

    @Test func loadHydratesAllSections() async throws {
        let mock = FakeJellyfinClient()
        mock.liveTvRecordingsResult = .success([
            BaseItemDto(id: "rec-1", name: "Rec 1"),
        ])
        mock.liveTvTimersResult = .success([
            TimerInfoDto(id: "t-1", name: "Future", startDate: Date().addingTimeInterval(3600)),
        ])
        mock.liveTvSeriesTimersResult = .success([
            SeriesTimerInfoDto(id: "ser-1", name: "Series 1", recordNewOnly: true),
        ])

        let model = RecordingsModel(client: mock)
        await model.load()

        guard case .loaded(let content) = model.state else {
            Issue.record("Expected loaded, got \(model.state)")
            return
        }
        #expect(content.scheduled.count == 1)
        #expect(content.series.count == 1)
        // `library` and `recording` come from the same recordings stub here,
        // both should resolve.
        #expect(content.library.count == 1)
        #expect(content.recording.count == 1)
    }

    @Test func pastTimersAreFilteredOut() async throws {
        let mock = FakeJellyfinClient()
        mock.liveTvRecordingsResult = .success([])
        mock.liveTvTimersResult = .success([
            TimerInfoDto(id: "old", name: "Yesterday", startDate: Date().addingTimeInterval(-3600)),
            TimerInfoDto(id: "new", name: "Tomorrow", startDate: Date().addingTimeInterval(3600)),
        ])
        mock.liveTvSeriesTimersResult = .success([])

        let model = RecordingsModel(client: mock)
        await model.load()

        guard case .loaded(let content) = model.state else {
            Issue.record("Expected loaded")
            return
        }
        #expect(content.scheduled.map(\.id) == ["new"])
    }
}
