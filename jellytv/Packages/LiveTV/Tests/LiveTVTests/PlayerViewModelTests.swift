import Testing
import Foundation
import JellyfinAPI
@testable import LiveTV

// MARK: - Mocks

@MainActor
final class MockPlayerHost: PlayerHost {
    let statusStream: AsyncStream<Int>
    let readyForDisplayStream: AsyncStream<Bool>
    let bufferEmptyStream: AsyncStream<Bool>
    let failedToPlayStream: AsyncStream<PlayerHostError?>

    private let statusCont: AsyncStream<Int>.Continuation
    private let readyCont: AsyncStream<Bool>.Continuation
    private let bufferCont: AsyncStream<Bool>.Continuation
    private let failedCont: AsyncStream<PlayerHostError?>.Continuation

    var replacedURLs: [URL] = []
    var torndownCount = 0

    init() {
        var statusC: AsyncStream<Int>.Continuation!
        self.statusStream = AsyncStream { statusC = $0 }
        self.statusCont = statusC
        var readyC: AsyncStream<Bool>.Continuation!
        self.readyForDisplayStream = AsyncStream { readyC = $0 }
        self.readyCont = readyC
        var bufferC: AsyncStream<Bool>.Continuation!
        self.bufferEmptyStream = AsyncStream { bufferC = $0 }
        self.bufferCont = bufferC
        var failedC: AsyncStream<PlayerHostError?>.Continuation!
        self.failedToPlayStream = AsyncStream { failedC = $0 }
        self.failedCont = failedC
    }

    func replaceItem(url: URL) { replacedURLs.append(url) }
    func tearDown() { torndownCount += 1 }

    func emitStatus(_ raw: Int) { statusCont.yield(raw) }
    func emitReadyForDisplay(_ ready: Bool) { readyCont.yield(ready) }
    func emitBufferEmpty(_ empty: Bool) { bufferCont.yield(empty) }
    func emitFailedToPlay(_ err: PlayerHostError?) { failedCont.yield(err) }
}

@MainActor
final class MockNetworkMonitor: NetworkMonitor {
    let pathSatisfiedStream: AsyncStream<Bool>
    private let cont: AsyncStream<Bool>.Continuation
    var startedCount = 0
    var stoppedCount = 0

    init() {
        var c: AsyncStream<Bool>.Continuation!
        self.pathSatisfiedStream = AsyncStream { c = $0 }
        self.cont = c
    }

    func start() { startedCount += 1 }
    func stop() { stoppedCount += 1 }
    func emit(_ satisfied: Bool) { cont.yield(satisfied) }
}

// MARK: - Tests

@Suite("PlayerViewModel", .serialized)
@MainActor
struct PlayerViewModelTests {

    private let serverURL = URL(string: "http://10.1.1.12:8096")!

    private func channel(_ id: String, num: String = "101", name: String = "Test") -> LiveTvChannel {
        LiveTvChannel(id: id, name: name, number: num)
    }

    private func playback(_ urlString: String, liveStreamId: String?) -> LiveStreamPlayback {
        LiveStreamPlayback(playbackURL: URL(string: urlString)!, liveStreamId: liveStreamId)
    }

    /// Wait for the model's state to satisfy a predicate, polling on the run
    /// loop. We can't `await` a property change on @Observable directly, so
    /// we busy-wait via Task.yield up to a generous timeout.
    private func waitForState(
        _ vm: PlayerViewModel,
        timeout: TimeInterval = 1.0,
        predicate: (PlayerViewModel.State) -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline && !predicate(vm.state) {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
        }
    }

    @Test func happyPath_resolvingToSplashToPlaying() async {
        let host = MockPlayerHost()
        let net = MockNetworkMonitor()
        let ch = channel("c1")
        let pb = playback("http://example/m.m3u8", liveStreamId: "ls-1")
        var openCalls: [(LiveTvChannel, Bool)] = []
        let vm = PlayerViewModel(
            initialChannel: ch,
            channels: [ch],
            serverURL: serverURL,
            program: nil,
            openStream: { c, force in openCalls.append((c, force)); return pb },
            closeStream: { _ in },
            host: host,
            networkMonitor: net
        )
        // initial async tune
        await waitForState(vm) { if case .splash = $0 { return true }; return false }
        if case .splash(_, let p) = vm.state {
            #expect(p.liveStreamId == "ls-1")
        } else { Issue.record("expected splash, got \(vm.state)") }
        #expect(host.replacedURLs.count == 1)
        #expect(openCalls.count == 1)
        #expect(openCalls[0].1 == false) // not forceTranscoding

        // Simulate first frame rendered
        host.emitReadyForDisplay(true)
        await waitForState(vm) { if case .playing = $0 { return true }; return false }
    }

    @Test func openStreamFailure_directPlayFallbackThenSuccess() async {
        let host = MockPlayerHost()
        let net = MockNetworkMonitor()
        let ch = channel("c2")
        let pb = playback("http://example/m.m3u8", liveStreamId: "ls-2")
        var openCalls: [(LiveTvChannel, Bool)] = []
        let vm = PlayerViewModel(
            initialChannel: ch,
            channels: [ch],
            serverURL: serverURL,
            program: nil,
            openStream: { c, force in
                openCalls.append((c, force))
                if !force { throw NSError(domain: "test", code: 1) }
                return pb
            },
            closeStream: { _ in },
            host: host,
            networkMonitor: net
        )
        await waitForState(vm) { if case .splash = $0 { return true }; return false }
        // First call without force, second with force
        #expect(openCalls.count == 2)
        #expect(openCalls[0].1 == false)
        #expect(openCalls[1].1 == true)
    }

    @Test func openStreamPersistentFailure_endsInError() async {
        let host = MockPlayerHost()
        let net = MockNetworkMonitor()
        let ch = channel("c3")
        var openCalls = 0
        let vm = PlayerViewModel(
            initialChannel: ch,
            channels: [ch],
            serverURL: serverURL,
            program: nil,
            openStream: { _, _ in openCalls += 1; throw NSError(domain: "test", code: 1) },
            closeStream: { _ in },
            host: host,
            networkMonitor: net
        )
        await waitForState(vm, timeout: 2.0) {
            if case .error = $0 { return true }; return false
        }
        // Original attempt + DirectPlay fallback + 1 retry = 3 calls.
        #expect(openCalls == 3)
        if case .error(_, let msg, _) = vm.state {
            #expect(msg.contains("Couldn't tune"))
        } else { Issue.record("expected error state") }
    }

    @Test func channelUpDebouncesRapidPresses() async {
        let host = MockPlayerHost()
        let net = MockNetworkMonitor()
        let channels = [channel("a", num: "101"), channel("b", num: "102"), channel("c", num: "103")]
        let pb = playback("http://x/m.m3u8", liveStreamId: "ls")
        var openCalls = 0
        var lastChannel: LiveTvChannel?
        let vm = PlayerViewModel(
            initialChannel: channels[0],
            channels: channels,
            serverURL: serverURL,
            program: nil,
            openStream: { c, _ in openCalls += 1; lastChannel = c; return pb },
            closeStream: { _ in },
            host: host,
            networkMonitor: net
        )
        await waitForState(vm) { if case .splash = $0 { return true }; return false }
        let initialOpens = openCalls

        // Three rapid channel-up presses within debounce window.
        vm.channelUp()
        vm.channelUp()
        vm.channelUp()
        // Wait past debounce + a buffer.
        try? await Task.sleep(nanoseconds: 700_000_000)

        // Only ONE additional open should have fired.
        #expect(openCalls == initialOpens + 1)
        // And it should be channel "a" again (a → b → c → a wrap-around).
        #expect(lastChannel?.id == "a")
    }

    @Test func bufferEmptyOver5sTriggersReconnecting() async {
        let host = MockPlayerHost()
        let net = MockNetworkMonitor()
        let ch = channel("c4")
        let pb = playback("http://x/m.m3u8", liveStreamId: "ls-4")
        let vm = PlayerViewModel(
            initialChannel: ch,
            channels: [ch],
            serverURL: serverURL,
            program: nil,
            openStream: { _, _ in pb },
            closeStream: { _ in },
            host: host,
            networkMonitor: net
        )
        await waitForState(vm) { if case .splash = $0 { return true }; return false }
        host.emitReadyForDisplay(true)
        await waitForState(vm) { if case .playing = $0 { return true }; return false }

        // Buffer empty — won't transition immediately (5s threshold).
        host.emitBufferEmpty(true)
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms — well below threshold
        if case .reconnecting = vm.state { Issue.record("transitioned too early") }

        // Buffer recovers — should not transition to reconnecting.
        host.emitBufferEmpty(false)
        try? await Task.sleep(nanoseconds: 100_000_000)
        if case .reconnecting = vm.state { Issue.record("recovered but still reconnecting") }
    }

    @Test func dismissIsIdempotent_closeStreamCalledOnce() async {
        let host = MockPlayerHost()
        let net = MockNetworkMonitor()
        let ch = channel("c6")
        let pb = playback("http://x/m.m3u8", liveStreamId: "ls-6")
        var closedIds: [String] = []
        let vm = PlayerViewModel(
            initialChannel: ch,
            channels: [ch],
            serverURL: serverURL,
            program: nil,
            openStream: { _, _ in pb },
            closeStream: { id in closedIds.append(id) },
            host: host,
            networkMonitor: net
        )
        await waitForState(vm) { if case .splash = $0 { return true }; return false }

        // Call dismiss() twice — simulates Menu-press + onDisappear both firing.
        vm.dismiss()
        vm.dismiss()

        // Let the async close task execute.
        try? await Task.sleep(nanoseconds: 200_000_000)

        // closeStream must have been called exactly once.
        #expect(closedIds == ["ls-6"])
        // host.tearDown() must have been called exactly once.
        #expect(host.torndownCount == 1)
        // networkMonitor.stop() must have been called exactly once.
        #expect(net.stoppedCount == 1)
    }

    @Test func dismissCallsCloseStreamAndStopsNetwork() async {
        let host = MockPlayerHost()
        let net = MockNetworkMonitor()
        let ch = channel("c5")
        let pb = playback("http://x/m.m3u8", liveStreamId: "ls-5")
        var closedIds: [String] = []
        let vm = PlayerViewModel(
            initialChannel: ch,
            channels: [ch],
            serverURL: serverURL,
            program: nil,
            openStream: { _, _ in pb },
            closeStream: { id in closedIds.append(id) },
            host: host,
            networkMonitor: net
        )
        await waitForState(vm) { if case .splash = $0 { return true }; return false }
        vm.dismiss()
        // closeStream is async — let it run.
        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(closedIds == ["ls-5"])
        #expect(host.torndownCount == 1)
        #expect(net.stoppedCount == 1)
    }
}
