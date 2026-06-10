import Foundation
import Observation
import JellyfinAPI

/// Backs `PlaybillView` — the full channel lineup with each channel's
/// currently-airing program, sorted by channel number. Pulls through the
/// shared `EPGStore` so tab switches hit cache.
@MainActor
@Observable
public final class PlaybillModel {
    public enum State: Equatable, Sendable {
        case loading
        case loaded([LiveTvChannel])
        case failed(String)
    }

    public private(set) var state: State = .loading
    private let store: EPGStore

    public init(store: EPGStore) {
        self.store = store
    }

    public func load() async {
        state = .loading
        do {
            let channels = try await store.channels(
                filters: LiveTvChannelFilters(sortBy: "SortName", sortOrder: "Ascending"),
                addCurrentProgram: true
            )
            state = .loaded(ChannelOrdering.sortedByChannelNumber(channels))
        } catch JellyfinError.network {
            state = .failed("Couldn't reach the server.")
        } catch JellyfinError.unauthenticated {
            state = .failed("Session expired. Please sign in again.")
        } catch {
            JellytvLog.liveTV.error("PlaybillModel.load: \(String(describing: error), privacy: .public)")
            state = .failed("Something went wrong loading channels.")
        }
    }
}
