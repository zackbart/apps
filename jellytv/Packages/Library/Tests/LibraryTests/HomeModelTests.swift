import Testing
import Foundation
import JellyfinAPI
import Library

@MainActor
final class HomeModelTests {
    private func makeMock() -> (HomeModel, TestMockClient) {
        let mock = TestMockClient()
        let model = HomeModel(client: mock)
        return (model, mock)
    }

    @Test
    func loadSuccess() async throws {
        let (model, mock) = makeMock()

        mock.userViewsResult = .success([
            BaseItemDto(id: "lib1", name: "Movies", type: "Folder", serverId: nil, parentId: nil, imageTags: nil, backdropImageTags: nil, overview: nil, productionYear: nil, userData: nil, runTimeTicks: nil, seriesName: nil, seasonName: nil, indexNumber: nil, communityRating: nil)
        ])
        mock.resumeItemsResult = .success([
            BaseItemDto(id: "item1", name: "In Progress", type: "Movie", serverId: nil, parentId: nil, imageTags: ["Primary": "tag1"], backdropImageTags: nil, overview: "A movie", productionYear: 2024, userData: nil, runTimeTicks: 7200000000, seriesName: nil, seasonName: nil, indexNumber: nil, communityRating: nil)
        ])
        mock.nextUpResult = .success([])
        mock.latestItemsResult = .success([])

        mock.currentServerURL_ = URL(string: "http://localhost:8096")

        await model.load()

        switch model.state {
        case .loaded:
            return
        case .loading:
            Issue.record("Never left loading state")
        case .failed(let msg):
            Issue.record("Failed: \(msg)")
        }
    }

    @Test
    func loadNetworkError() async throws {
        let (model, mock) = makeMock()

        mock.userViewsResult = .failure(JellyfinError.network(URLError(.notConnectedToInternet)))
        mock.currentServerURL_ = URL(string: "http://localhost:8096")

        await model.load()

        guard case .failed(let message) = model.state else {
            Issue.record("Expected failed state")
            return
        }
        #expect(message.contains("reach"))
    }

    @Test
    func loadNoServerURL() async throws {
        let (model, mock) = makeMock()

        mock.currentServerURL_ = nil

        await model.load()

        guard case .failed(let message) = model.state else {
            Issue.record("Expected failed state")
            return
        }
        #expect(message.contains("signed in"))
    }

    @Test
    func loadUnauthorized() async throws {
        let (model, mock) = makeMock()

        mock.userViewsResult = .failure(JellyfinError.unauthenticated)
        mock.currentServerURL_ = URL(string: "http://localhost:8096")

        await model.load()

        guard case .failed(let message) = model.state else {
            Issue.record("Expected failed state")
            return
        }
        #expect(message.contains("Session"))
    }
}

private final class TestMockClient: JellyfinClientAPI, @unchecked Sendable {
    var setServerURLCalls: [URL?] = []
    var setAccessTokenCalls: [String?] = []
    var currentServerURL_: URL? = nil

    var userViewsResult: Result<[BaseItemDto], Error> = .success([])
    var resumeItemsResult: Result<[BaseItemDto], Error> = .success([])
    var nextUpResult: Result<[BaseItemDto], Error> = .success([])
    var latestItemsResult: Result<[BaseItemDto], Error> = .success([])

    func setServerURL(_ url: URL?) async {
        setServerURLCalls.append(url)
        currentServerURL_ = url
    }

    func currentServerURL() async -> URL? {
        currentServerURL_
    }

    func setAccessToken(_ token: String?) async {
        setAccessTokenCalls.append(token)
    }

    func getPublicSystemInfo() async throws -> PublicSystemInfo {
        PublicSystemInfo(serverName: "Test", version: "1.0", id: nil, productName: nil, localAddress: nil, startupWizardCompleted: nil)
    }

    func authenticateByName(username: String, password: String) async throws -> AuthenticationResult {
        throw JellyfinError.unauthenticated
    }

    func quickConnectEnabled() async throws -> Bool { false }
    func quickConnectInitiate() async throws -> QuickConnectResult { throw JellyfinError.unauthenticated }
    func quickConnectStatus(secret: String) async throws -> QuickConnectResult { throw JellyfinError.unauthenticated }
    func authenticateWithQuickConnect(secret: String) async throws -> AuthenticationResult { throw JellyfinError.unauthenticated }
    func currentUser() async throws -> UserDto { throw JellyfinError.unauthenticated }
    func logout() async throws {}

    func userViews() async throws -> [BaseItemDto] {
        try userViewsResult.get()
    }

    func resumeItems(limit: Int) async throws -> [BaseItemDto] {
        try resumeItemsResult.get()
    }

    func nextUp(limit: Int) async throws -> [BaseItemDto] {
        try nextUpResult.get()
    }

    func latestItems(parentId: String?, limit: Int) async throws -> [BaseItemDto] {
        try latestItemsResult.get()
    }

    func liveTvChannels() async throws -> [LiveTvChannel] { [] }

    func liveTvPrograms(
        channelIds: [String],
        minStartDate: Date,
        maxStartDate: Date
    ) async throws -> [LiveTvProgram] { [] }

    func liveTvOpenStream(channelId: String) async throws -> LiveStreamPlayback {
        LiveStreamPlayback(playbackURL: URL(string: "http://test/stream")!, liveStreamId: nil)
    }
}