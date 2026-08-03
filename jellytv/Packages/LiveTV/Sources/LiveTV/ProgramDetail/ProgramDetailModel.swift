import Foundation
import Observation
import JellyfinAPI

@MainActor
@Observable
public final class ProgramDetailModel {
    public enum RecordState: Equatable, Sendable {
        case unknown
        case notScheduled
        case scheduled(timerId: String)
        case recording(timerId: String)
        case error(String)
    }

    public private(set) var program: LiveTvProgram
    public private(set) var recordState: RecordState = .unknown
    public private(set) var isWorking: Bool = false

    private let client: any JellyfinClientAPI

    public init(program: LiveTvProgram, client: any JellyfinClientAPI) {
        self.program = program
        self.client = client
    }

    /// Refreshes the timer state (used by the Record button) by checking
    /// `/LiveTv/Timers` for an entry whose programId matches this program.
    public func refreshRecordState() async {
        do {
            let timers = try await client.liveTvTimers()
            if let timer = timers.first(where: { $0.programId == program.id }) {
                let status = timer.status?.lowercased() ?? ""
                if status == "inprogress" || status == "recording" {
                    recordState = .recording(timerId: timer.id)
                } else {
                    recordState = .scheduled(timerId: timer.id)
                }
            } else {
                recordState = .notScheduled
            }
        } catch {
            JellytvLog.liveTV.error("ProgramDetailModel.refreshRecordState: \(String(describing: error), privacy: .public)")
            recordState = .notScheduled
        }
    }

    /// Toggle: schedule a recording if not scheduled, cancel it if it is.
    /// Round-trips `liveTvTimerDefaults(programId:)` → `createLiveTvTimer(body:)`
    /// because Jellyfin's timer endpoint expects the full defaults document
    /// echoed back, with the programId pre-bound by the server.
    public func toggleRecording() async {
        if isWorking { return }
        isWorking = true
        defer { isWorking = false }

        switch recordState {
        case .scheduled(let timerId), .recording(let timerId):
            do {
                try await client.cancelLiveTvTimer(timerId: timerId)
                recordState = .notScheduled
            } catch {
                recordState = .error(error.localizedDescription)
            }
        case .notScheduled, .unknown, .error:
            do {
                let body = try await client.liveTvTimerDefaults(programId: program.id)
                try await client.createLiveTvTimer(body: body)
                await refreshRecordState()
            } catch {
                recordState = .error(error.localizedDescription)
            }
        }
    }
}
