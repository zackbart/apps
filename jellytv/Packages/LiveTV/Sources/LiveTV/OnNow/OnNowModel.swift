import Foundation
import Observation
import JellyfinAPI

/// Snapshot powering `OnNowView`. Each field corresponds to a horizontal
/// shelf in the Plex-style landing. Built from a fan-out of LiveTV API
/// queries: channels with addCurrentProgram, recommended programs, and a
/// recordings sample.
public struct OnNowContent: Sendable, Equatable {
    public let serverURL: URL
    public let onNow: [LiveTvChannel]
    public let movies: [LiveTvChannel]
    public let sports: [LiveTvChannel]
    public let news: [LiveTvChannel]
    public let kids: [LiveTvChannel]
    public let favorites: [LiveTvChannel]
    public let upNext: [LiveTvProgram]
    public let recentRecordings: [BaseItemDto]

    public init(
        serverURL: URL,
        onNow: [LiveTvChannel] = [],
        movies: [LiveTvChannel] = [],
        sports: [LiveTvChannel] = [],
        news: [LiveTvChannel] = [],
        kids: [LiveTvChannel] = [],
        favorites: [LiveTvChannel] = [],
        upNext: [LiveTvProgram] = [],
        recentRecordings: [BaseItemDto] = []
    ) {
        self.serverURL = serverURL
        self.onNow = onNow
        self.movies = movies
        self.sports = sports
        self.news = news
        self.kids = kids
        self.favorites = favorites
        self.upNext = upNext
        self.recentRecordings = recentRecordings
    }

    public var heroChannel: LiveTvChannel? {
        favorites.first ?? onNow.first ?? movies.first ?? sports.first
    }

    public var isEmpty: Bool {
        onNow.isEmpty && movies.isEmpty && sports.isEmpty && news.isEmpty
            && kids.isEmpty && favorites.isEmpty && upNext.isEmpty
            && recentRecordings.isEmpty
    }
}

@MainActor
@Observable
public final class OnNowModel {
    public enum State: Equatable, Sendable {
        case loading
        case loaded(OnNowContent)
        case failed(String)
    }

    public private(set) var state: State = .loading
    private let client: any JellyfinClientAPI
    private let store: EPGStore

    public init(client: any JellyfinClientAPI, store: EPGStore) {
        self.client = client
        self.store = store
    }

    public func load() async {
        JellytvLog.liveTV.info("OnNowModel.load() begin")
        state = .loading

        guard let serverURL = await client.currentServerURL() else {
            JellytvLog.liveTV.error("OnNowModel.load: not signed in")
            state = .failed("Not signed in")
            return
        }

        do {
            async let onNowTask = store.channels(
                filters: LiveTvChannelFilters(isAiringNow: true, sortBy: "SortName", sortOrder: "Ascending", limit: 60),
                addCurrentProgram: true
            )
            async let moviesTask = store.channels(
                filters: LiveTvChannelFilters(isMovie: true, isAiringNow: true, limit: 24),
                addCurrentProgram: true
            )
            async let sportsTask = store.channels(
                filters: LiveTvChannelFilters(isSports: true, isAiringNow: true, limit: 24),
                addCurrentProgram: true
            )
            async let newsTask = store.channels(
                filters: LiveTvChannelFilters(isNews: true, isAiringNow: true, limit: 24),
                addCurrentProgram: true
            )
            async let kidsTask = store.channels(
                filters: LiveTvChannelFilters(isKids: true, isAiringNow: true, limit: 24),
                addCurrentProgram: true
            )
            async let favoritesTask = store.channels(
                filters: LiveTvChannelFilters(isFavorite: true, sortBy: "SortName", sortOrder: "Ascending", limit: 24),
                addCurrentProgram: true
            )
            async let upNextTask = client.liveTvRecommendedPrograms(
                filters: LiveTvProgramFilters(hasAired: false, limit: 24)
            )
            async let recordingsTask = client.liveTvRecordings(isInProgress: nil, seriesTimerId: nil, limit: 24)

            let (onNow, movies, sports, news, kids, favorites, upNext, recordings) = try await (
                onNowTask,
                moviesTask,
                sportsTask,
                newsTask,
                kidsTask,
                favoritesTask,
                upNextTask,
                recordingsTask
            )

            // Filter sub-shelves to channels not already in `favorites` so the
            // top "Favorites" row doesn't duplicate the same tile lower down.
            let favoriteIds = Set(favorites.map(\.id))
            let dedup: ([LiveTvChannel]) -> [LiveTvChannel] = { channels in
                channels.filter { !favoriteIds.contains($0.id) }
            }

            let content = OnNowContent(
                serverURL: serverURL,
                onNow: dedup(onNow),
                movies: dedup(movies),
                sports: dedup(sports),
                news: dedup(news),
                kids: dedup(kids),
                favorites: favorites,
                upNext: upNext,
                recentRecordings: recordings
            )
            JellytvLog.liveTV.info("OnNowModel.load: onNow=\(onNow.count) movies=\(movies.count) sports=\(sports.count) news=\(news.count) kids=\(kids.count) fav=\(favorites.count) upNext=\(upNext.count) recordings=\(recordings.count)")
            state = .loaded(content)
        } catch JellyfinError.network {
            state = .failed("Couldn't reach the server.")
        } catch JellyfinError.unauthenticated {
            state = .failed("Session expired. Please sign in again.")
        } catch {
            JellytvLog.liveTV.error("OnNowModel.load: \(String(describing: error), privacy: .public)")
            state = .failed("Something went wrong loading Live TV.")
        }
    }
}
