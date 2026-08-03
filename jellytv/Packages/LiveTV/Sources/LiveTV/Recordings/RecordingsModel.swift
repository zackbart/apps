import Foundation
import Observation
import JellyfinAPI

public struct RecordingsContent: Sendable, Equatable {
    public let serverURL: URL
    public let recording: [BaseItemDto]
    public let library: [BaseItemDto]
    public let scheduled: [TimerInfoDto]
    public let series: [SeriesTimerInfoDto]

    public init(
        serverURL: URL,
        recording: [BaseItemDto] = [],
        library: [BaseItemDto] = [],
        scheduled: [TimerInfoDto] = [],
        series: [SeriesTimerInfoDto] = []
    ) {
        self.serverURL = serverURL
        self.recording = recording
        self.library = library
        self.scheduled = scheduled
        self.series = series
    }

    public var isEmpty: Bool {
        recording.isEmpty && library.isEmpty && scheduled.isEmpty && series.isEmpty
    }
}

@MainActor
@Observable
public final class RecordingsModel {
    public enum State: Equatable, Sendable {
        case loading
        case loaded(RecordingsContent)
        case failed(String)
    }

    public private(set) var state: State = .loading
    private let client: any JellyfinClientAPI

    public init(client: any JellyfinClientAPI) {
        self.client = client
    }

    public func load() async {
        state = .loading
        guard let serverURL = await client.currentServerURL() else {
            state = .failed("Not signed in")
            return
        }
        do {
            async let inProgressTask = client.liveTvRecordings(isInProgress: true, seriesTimerId: nil, limit: 60)
            async let libraryTask = client.liveTvRecordings(isInProgress: false, seriesTimerId: nil, limit: 100)
            async let timersTask = client.liveTvTimers()
            async let seriesTask = client.liveTvSeriesTimers()

            let (inProgress, library, timers, series) = try await (
                inProgressTask, libraryTask, timersTask, seriesTask
            )

            // Filter out scheduled timers that are already recording (those
            // appear in `inProgress`) so the "Scheduled" row only shows future
            // recordings.
            let now = Date()
            let upcoming = timers.filter { timer in
                guard let start = timer.startDate else { return true }
                return start > now
            }

            let content = RecordingsContent(
                serverURL: serverURL,
                recording: inProgress,
                library: library,
                scheduled: upcoming,
                series: series
            )
            state = .loaded(content)
        } catch JellyfinError.network {
            state = .failed("Couldn't reach the server.")
        } catch JellyfinError.unauthenticated {
            state = .failed("Session expired. Please sign in again.")
        } catch {
            state = .failed("Couldn't load recordings.")
        }
    }

    public func deleteRecording(_ item: BaseItemDto) async {
        do {
            try await client.deleteLiveTvRecording(recordingId: item.id)
            await load()
        } catch {
            JellytvLog.liveTV.error("RecordingsModel.deleteRecording: \(String(describing: error), privacy: .public)")
        }
    }

    public func cancelTimer(_ timer: TimerInfoDto) async {
        do {
            try await client.cancelLiveTvTimer(timerId: timer.id)
            await load()
        } catch {
            JellytvLog.liveTV.error("RecordingsModel.cancelTimer: \(String(describing: error), privacy: .public)")
        }
    }

    public func cancelSeriesTimer(_ timer: SeriesTimerInfoDto) async {
        do {
            try await client.cancelLiveTvSeriesTimer(timerId: timer.id)
            await load()
        } catch {
            JellytvLog.liveTV.error("RecordingsModel.cancelSeriesTimer: \(String(describing: error), privacy: .public)")
        }
    }
}
