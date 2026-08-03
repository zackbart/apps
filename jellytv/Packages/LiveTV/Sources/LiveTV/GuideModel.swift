import Foundation
import Observation
import JellyfinAPI

/// Top-level filter on the EPG guide. Drives both the channel-list query
/// (`isMovie` / `isSports` / etc.) and the chrome of `CategoryFilterBar`.
public enum GuideCategory: String, CaseIterable, Sendable, Identifiable {
    case all
    case favorites
    case movies
    case sports
    case news
    case kids

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "All"
        case .favorites: return "Favorites"
        case .movies: return "Movies"
        case .sports: return "Sports"
        case .news: return "News"
        case .kids: return "Kids"
        }
    }

    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .favorites: return "star.fill"
        case .movies: return "film"
        case .sports: return "sportscourt"
        case .news: return "newspaper"
        case .kids: return "figure.and.child.holdinghands"
        }
    }

    public var channelFilters: LiveTvChannelFilters {
        switch self {
        case .all: return .default
        case .favorites: return .favorites
        case .movies: return .movies
        case .sports: return .sports
        case .news: return .news
        case .kids: return .kids
        }
    }
}

@MainActor
@Observable
public final class GuideModel {
    public enum State: Equatable, Sendable {
        case loading
        case loaded(GuideContent)
        case failed(String)
    }

    public private(set) var state: State = .loading
    public private(set) var categoryFilter: GuideCategory = .all

    private let client: any JellyfinClientAPI
    private let store: EPGStore
    private let now: @Sendable () -> Date

    public init(
        client: any JellyfinClientAPI,
        store: EPGStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.store = store
        self.now = now
    }

    public func load() async {
        await load(filter: categoryFilter)
    }

    public func applyFilter(_ filter: GuideCategory) async {
        categoryFilter = filter
        await load(filter: filter)
    }

    private func load(filter: GuideCategory) async {
        JellytvLog.liveTV.info("GuideModel.load(filter: \(filter.rawValue, privacy: .public))")
        state = .loading

        guard let serverURL = await client.currentServerURL() else {
            JellytvLog.liveTV.error("GuideModel.load: not signed in (no serverURL)")
            state = .failed("Not signed in")
            return
        }

        let windowStart = now()
        let windowEnd = windowStart.addingTimeInterval(GuideLayout.futureWindowSeconds)
        let fetchStart = windowStart.addingTimeInterval(-GuideLayout.pastWindowSeconds)

        do {
            let channels: [LiveTvChannel]
            if filter == .all {
                channels = try await store.channels()
            } else {
                channels = try await store.channels(
                    filters: filter.channelFilters,
                    addCurrentProgram: false
                )
            }
            let validChannelIds = Set(channels.map(\.id))
            let programs: [LiveTvProgram]
            if channels.isEmpty {
                programs = []
            } else {
                programs = try await client.liveTvPrograms(
                    channelIds: channels.map(\.id),
                    minStartDate: fetchStart,
                    maxStartDate: windowEnd
                )
            }

            var grouped: [String: [LiveTvProgram]] = [:]
            for program in programs {
                guard let channelId = program.channelId,
                      validChannelIds.contains(channelId) else { continue }
                if let endDate = program.endDate, endDate <= windowStart { continue }
                grouped[channelId, default: []].append(program)
            }
            for (channelId, list) in grouped {
                grouped[channelId] = list.sorted { lhs, rhs in
                    (lhs.startDate ?? .distantPast) < (rhs.startDate ?? .distantPast)
                }
            }

            let content = GuideContent(
                serverURL: serverURL,
                windowStart: windowStart,
                windowEnd: windowEnd,
                channels: channels,
                programsByChannel: grouped
            )
            JellytvLog.liveTV.info("GuideModel.load: loaded \(channels.count) channels, \(programs.count) programs")
            state = .loaded(content)
        } catch JellyfinError.network {
            JellytvLog.liveTV.error("GuideModel.load: network failure")
            state = .failed("Couldn't reach the server.")
        } catch JellyfinError.unauthenticated {
            JellytvLog.liveTV.error("GuideModel.load: unauthenticated")
            state = .failed("Session expired. Please sign in again.")
        } catch {
            JellytvLog.liveTV.error("GuideModel.load: \(String(describing: error), privacy: .public)")
            state = .failed("Something went wrong: \(error)")
        }
    }

    /// Resolves the live playback URL for a channel. Delegates to the
    /// underlying client so that token + URL construction stay encapsulated.
    public func openStream(channelId: String) async throws -> LiveStreamPlayback {
        try await client.liveTvOpenStream(channelId: channelId)
    }
}
