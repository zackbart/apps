import Testing
import Foundation
import JellyfinAPI
import Library

@MainActor
final class HomeModelScrollRegressionTests {
    private func makeMock() -> (HomeModel, TestScrollRegressionClient) {
        let mock = TestScrollRegressionClient()
        let model = HomeModel(client: mock)
        return (model, mock)
    }

    @Test
    func testNoDuplicateIdsInLatestShelves() async throws {
        let (model, mock) = makeMock()

        mock.currentServerURL_ = URL(string: "http://localhost:8096")

        var libraryItems: [BaseItemDto] = []
        for i in 0..<500 {
            libraryItems.append(BaseItemDto(
                id: "item-\(i)",
                name: "Movie \(i)",
                type: "Movie",
                serverId: nil,
                parentId: nil,
                imageTags: nil,
                backdropImageTags: nil,
                overview: nil,
                productionYear: nil,
                userData: nil,
                runTimeTicks: nil,
                seriesName: nil,
                seasonName: nil,
                indexNumber: nil,
                communityRating: nil
            ))
        }

        mock.userViewsResult = .success([
            BaseItemDto(id: "lib1", name: "Movies", type: "Folder", serverId: nil, parentId: nil, imageTags: nil, backdropImageTags: nil, overview: nil, productionYear: nil, userData: nil, runTimeTicks: nil, seriesName: nil, seasonName: nil, indexNumber: nil, communityRating: nil)
        ])
        mock.resumeItemsResult = .success([])
        mock.nextUpResult = .success([])
        mock.latestItemsResult = .success(libraryItems)

        await model.load()

        guard case .loaded(let content) = model.state else {
            Issue.record("Expected loaded state")
            return
        }

        let latestItems = content.latestPerLibrary["lib1"] ?? []
        let ids = latestItems.map { $0.id }
        let uniqueIds = Set(ids)

        #expect(ids.count == uniqueIds.count)
    }

    @Test
    func testLargeLibraryDoesNotCrash() async throws {
        let (model, mock) = makeMock()

        mock.currentServerURL_ = URL(string: "http://localhost:8096")

        var libraryItems: [BaseItemDto] = []
        for i in 0..<500 {
            libraryItems.append(BaseItemDto(
                id: "item-\(i)",
                name: "Movie \(i)",
                type: "Movie",
                serverId: nil,
                parentId: nil,
                imageTags: nil,
                backdropImageTags: nil,
                overview: nil,
                productionYear: nil,
                userData: nil,
                runTimeTicks: nil,
                seriesName: nil,
                seasonName: nil,
                indexNumber: nil,
                communityRating: nil
            ))
        }

        mock.userViewsResult = .success([
            BaseItemDto(id: "lib1", name: "Movies", type: "Folder", serverId: nil, parentId: nil, imageTags: nil, backdropImageTags: nil, overview: nil, productionYear: nil, userData: nil, runTimeTicks: nil, seriesName: nil, seasonName: nil, indexNumber: nil, communityRating: nil)
        ])
        mock.resumeItemsResult = .success([])
        mock.nextUpResult = .success([])
        mock.latestItemsResult = .success(libraryItems)

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
}

private final class TestScrollRegressionClient: JellyfinClientAPI, @unchecked Sendable {
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