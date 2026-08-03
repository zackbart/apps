import Testing
import Foundation
@testable import JellyfinAPI

/// Dedicated stub class so this suite's static handler doesn't race with
/// other suites (Swift Testing parallelizes across suites).
final class LiveTvExtendedStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = LiveTvExtendedStubURLProtocol.handler else {
            fatalError("LiveTvExtendedStubURLProtocol.handler not set")
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("JellyfinClient LiveTV Extended", .serialized)
struct JellyfinClientLiveTvExtendedTests {

    private let serverURL = URL(string: "http://192.168.1.50:8096")!

    private func makeStubbedClient(
        handler: @escaping (URLRequest) -> (HTTPURLResponse, Data)
    ) -> JellyfinClient {
        LiveTvExtendedStubURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LiveTvExtendedStubURLProtocol.self]
        let session = URLSession(configuration: config)
        return JellyfinClient(
            deviceId: "test-device-id",
            clientName: "JellyTV",
            clientVersion: "1.0",
            deviceName: "Apple TV",
            session: session
        )
    }

    private func ok(_ json: String, url: URL) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!, Data(json.utf8))
    }

    private func okData(_ data: Data, url: URL) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!, data)
    }

    // MARK: - Channels with filters

    @Test func liveTvChannelsWithFiltersIncludesFlags() async throws {
        var capturedURL: URL?
        let client = makeStubbedClient { request in
            capturedURL = request.url
            return self.ok("""
            { "Items": [], "TotalRecordCount": 0 }
            """, url: request.url!)
        }
        await client.setServerURL(serverURL)
        _ = try await client.liveTvChannels(
            filters: LiveTvChannelFilters(
                isMovie: nil,
                isSports: true,
                isFavorite: true,
                isAiringNow: true,
                limit: 50
            ),
            addCurrentProgram: true
        )

        let url = try #require(capturedURL)
        #expect(url.path == "/LiveTv/Channels")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let nameMap: [String: String] = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            guard let v = item.value else { return nil }
            return (item.name, v)
        })
        #expect(nameMap["isSports"] == "true")
        #expect(nameMap["isFavorite"] == "true")
        #expect(nameMap["isAiring"] == "true")
        #expect(nameMap["addCurrentProgram"] == "true")
        #expect(nameMap["limit"] == "50")
        #expect(nameMap["enableImages"] == "true")
    }

    // MARK: - Recommended Programs

    @Test func liveTvRecommendedProgramsHitsCorrectPath() async throws {
        var capturedURL: URL?
        let client = makeStubbedClient { request in
            capturedURL = request.url
            return self.ok("""
            { "Items": [
                { "Id": "p1", "Name": "Up Next" }
            ] }
            """, url: request.url!)
        }
        await client.setServerURL(serverURL)
        let programs = try await client.liveTvRecommendedPrograms(
            filters: LiveTvProgramFilters(hasAired: false, isMovie: true, limit: 12)
        )
        #expect(programs.count == 1)
        #expect(programs[0].name == "Up Next")

        let url = try #require(capturedURL)
        #expect(url.path == "/LiveTv/Programs/Recommended")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let nameMap: [String: String] = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            guard let v = item.value else { return nil }
            return (item.name, v)
        })
        #expect(nameMap["isMovie"] == "true")
        #expect(nameMap["hasAired"] == "false")
        #expect(nameMap["limit"] == "12")
    }

    // MARK: - Recordings

    @Test func liveTvRecordingsInProgress() async throws {
        var capturedURL: URL?
        let client = makeStubbedClient { request in
            capturedURL = request.url
            return self.ok("""
            { "Items": [
                { "Id": "rec-1", "Name": "Recording" }
            ] }
            """, url: request.url!)
        }
        await client.setServerURL(serverURL)
        let recordings = try await client.liveTvRecordings(isInProgress: true, seriesTimerId: nil, limit: 10)
        #expect(recordings.count == 1)
        #expect(recordings[0].id == "rec-1")

        let url = try #require(capturedURL)
        #expect(url.path == "/LiveTv/Recordings")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let nameMap: [String: String] = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            guard let v = item.value else { return nil }
            return (item.name, v)
        })
        #expect(nameMap["isInProgress"] == "true")
        #expect(nameMap["limit"] == "10")
    }

    @Test func deleteLiveTvRecordingHitsDeletePath() async throws {
        var capturedURL: URL?
        var capturedMethod: String?
        let client = makeStubbedClient { request in
            capturedURL = request.url
            capturedMethod = request.httpMethod
            return self.okData(Data(), url: request.url!)
        }
        await client.setServerURL(serverURL)
        try await client.deleteLiveTvRecording(recordingId: "rec-42")

        let url = try #require(capturedURL)
        #expect(url.path == "/LiveTv/Recordings/rec-42")
        #expect(capturedMethod == "DELETE")
    }

    // MARK: - Timers

    @Test func liveTvTimersDecodesItems() async throws {
        let client = makeStubbedClient { request in
            self.ok("""
            { "Items": [
                { "Id": "t1", "Name": "Game", "ChannelId": "ch-1", "Status": "New" },
                { "Id": "t2", "Name": "News", "ChannelId": "ch-2" }
            ] }
            """, url: request.url!)
        }
        await client.setServerURL(serverURL)
        let timers = try await client.liveTvTimers()
        #expect(timers.count == 2)
        #expect(timers[0].id == "t1")
        #expect(timers[0].status == "New")
        #expect(timers[1].channelId == "ch-2")
    }

    @Test func liveTvSeriesTimersDecodesItems() async throws {
        let client = makeStubbedClient { request in
            self.ok("""
            { "Items": [
                { "Id": "s1", "Name": "Series A", "RecordNewOnly": true }
            ] }
            """, url: request.url!)
        }
        await client.setServerURL(serverURL)
        let timers = try await client.liveTvSeriesTimers()
        #expect(timers.count == 1)
        #expect(timers[0].id == "s1")
        #expect(timers[0].recordNewOnly == true)
    }

    @Test func cancelLiveTvTimerHitsDelete() async throws {
        var capturedURL: URL?
        var capturedMethod: String?
        let client = makeStubbedClient { request in
            capturedURL = request.url
            capturedMethod = request.httpMethod
            return self.okData(Data(), url: request.url!)
        }
        await client.setServerURL(serverURL)
        try await client.cancelLiveTvTimer(timerId: "t-99")
        let url = try #require(capturedURL)
        #expect(url.path == "/LiveTv/Timers/t-99")
        #expect(capturedMethod == "DELETE")
    }

    @Test func cancelSeriesTimerHitsDelete() async throws {
        var capturedURL: URL?
        var capturedMethod: String?
        let client = makeStubbedClient { request in
            capturedURL = request.url
            capturedMethod = request.httpMethod
            return self.okData(Data(), url: request.url!)
        }
        await client.setServerURL(serverURL)
        try await client.cancelLiveTvSeriesTimer(timerId: "s-99")
        let url = try #require(capturedURL)
        #expect(url.path == "/LiveTv/SeriesTimers/s-99")
        #expect(capturedMethod == "DELETE")
    }

    @Test func liveTvTimerDefaultsRoundTripsBody() async throws {
        let payload = #"{"ChannelId":"ch-1","ProgramId":"prog-1"}"#
        let client = makeStubbedClient { request in
            self.ok(payload, url: request.url!)
        }
        await client.setServerURL(serverURL)
        let body = try await client.liveTvTimerDefaults(programId: "prog-1")
        #expect(body == Data(payload.utf8))
    }

    // MARK: - Favorites

    @Test func setFavoriteTrueIsPost() async throws {
        var capturedURL: URL?
        var capturedMethod: String?
        let client = makeStubbedClient { request in
            capturedURL = request.url
            capturedMethod = request.httpMethod
            return self.okData(Data(), url: request.url!)
        }
        await client.setServerURL(serverURL)
        try await client.setFavorite(itemId: "ch-7", isFavorite: true)
        let url = try #require(capturedURL)
        #expect(url.path == "/UserFavoriteItems/ch-7")
        #expect(capturedMethod == "POST")
    }

    @Test func setFavoriteFalseIsDelete() async throws {
        var capturedMethod: String?
        let client = makeStubbedClient { request in
            capturedMethod = request.httpMethod
            return self.okData(Data(), url: request.url!)
        }
        await client.setServerURL(serverURL)
        try await client.setFavorite(itemId: "ch-7", isFavorite: false)
        #expect(capturedMethod == "DELETE")
    }
}
