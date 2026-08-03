import Foundation
import Network

/// Abstracts `NWPathMonitor` so tests can drive path-status changes
/// synchronously. Used by `PlayerViewModel` as a *secondary* signal — the
/// primary trigger for the reconnect path is `AVPlayerItem.playbackBufferEmpty`
/// for >5s. Network-restored events here just nudge the model to retry sooner
/// if it's already reconnecting; they don't tear down a healthy stream.
@MainActor
public protocol NetworkMonitor: AnyObject, Sendable {
    /// Emits true when the network is satisfied (reachable), false when it
    /// drops or becomes unsatisfied.
    var pathSatisfiedStream: AsyncStream<Bool> { get }

    /// Begin observation. Idempotent.
    func start()

    /// Stop observation; release underlying resources.
    func stop()
}

/// Real implementation backed by `NWPathMonitor`.
@MainActor
public final class NWPathNetworkMonitor: NetworkMonitor {
    public let pathSatisfiedStream: AsyncStream<Bool>
    private var continuation: AsyncStream<Bool>.Continuation?

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private var started = false

    public init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "tv.jelly.JellyTV.networkmonitor")
        var cont: AsyncStream<Bool>.Continuation!
        self.pathSatisfiedStream = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    public func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let satisfied = path.status == .satisfied
            Task { @MainActor in
                self.continuation?.yield(satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        monitor.cancel()
        continuation?.finish()
        started = false
    }
}
