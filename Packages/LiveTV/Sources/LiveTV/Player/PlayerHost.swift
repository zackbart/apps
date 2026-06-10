import Foundation
#if os(tvOS)
import AVKit
import AVFoundation
import UIKit
#endif

/// Abstracts the AVKit-shaped lifecycle the `PlayerViewModel` needs into a
/// protocol so tests can drive state transitions deterministically without
/// instantiating an `AVPlayer`. The real implementation
/// (`AVKitPlayerHost`) wraps `AVPlayerViewController` + `AVPlayer` + KVO; the
/// mock implementation (used in `PlayerViewModelTests`) emits state changes
/// synchronously via `AsyncStream` continuations the test holds onto.
@MainActor
public protocol PlayerHost: AnyObject, Sendable {
    /// Async stream of `AVPlayerItem.Status` raw values. Emits when the
    /// underlying item transitions to `.readyToPlay` (status == 1) or
    /// `.failed` (status == 2).
    var statusStream: AsyncStream<Int> { get }

    /// Async stream of `AVPlayerLayer.readyForDisplay` — true when the first
    /// frame is decoded and ready to render. Used to dismiss the splash only
    /// after pixels actually appear (not just on `.readyToPlay`).
    var readyForDisplayStream: AsyncStream<Bool> { get }

    /// Async stream of `AVPlayerItem.playbackBufferEmpty`. Emits true when
    /// the buffer drains mid-playback (likely network drop or transcoder
    /// stall) and false when it refills.
    var bufferEmptyStream: AsyncStream<Bool> { get }

    /// Async stream of `AVPlayerItemFailedToPlayToEndTime` notifications.
    /// Emits the underlying error (or nil if not surfaced).
    var failedToPlayStream: AsyncStream<PlayerHostError?> { get }

    /// Replace the currently-playing item with one for the given URL.
    /// First-time use opens the player at this URL.
    func replaceItem(url: URL)

    /// Tear down KVO + observers + the underlying AVPlayer. Called on dismiss.
    func tearDown()
}

/// Type-erased error wrapper because `Error` is not directly `Sendable`.
/// The real impl wraps `NSError`; the mock can pass a synthetic NSError.
public struct PlayerHostError: Sendable {
    public let domain: String
    public let code: Int
    public let localizedDescription: String

    public init(domain: String, code: Int, localizedDescription: String) {
        self.domain = domain
        self.code = code
        self.localizedDescription = localizedDescription
    }

    public init(_ error: Error) {
        let ns = error as NSError
        self.domain = ns.domain
        self.code = ns.code
        self.localizedDescription = ns.localizedDescription
    }
}

#if os(tvOS)

/// Real `PlayerHost` implementation: owns an `AVPlayer` + `AVPlayerLayer` for
/// `readyForDisplay` KVO, and exposes an `AVPlayerViewController` for the
/// SwiftUI view layer to render (via `UIViewControllerRepresentable`).
///
/// Status / readyForDisplay / bufferEmpty / failedToPlay are surfaced as
/// `AsyncStream`s so the view model can `for-await` them inside its
/// `start()` task.
@MainActor
public final class AVKitPlayerHost: NSObject, PlayerHost {
    let controller: PlayerHostingController
    private let player: AVPlayer

    /// Wire these up before presenting; they're called when the user presses
    /// up/down on the Siri Remote or vertical-swipes on the player view.
    var onChannelUp: (() -> Void)? {
        get { controller.onChannelUp }
        set { controller.onChannelUp = newValue }
    }
    var onChannelDown: (() -> Void)? {
        get { controller.onChannelDown }
        set { controller.onChannelDown = newValue }
    }

    private var statusContinuation: AsyncStream<Int>.Continuation?
    private var readyForDisplayContinuation: AsyncStream<Bool>.Continuation?
    private var bufferEmptyContinuation: AsyncStream<Bool>.Continuation?
    private var failedToPlayContinuation: AsyncStream<PlayerHostError?>.Continuation?

    public let statusStream: AsyncStream<Int>
    public let readyForDisplayStream: AsyncStream<Bool>
    public let bufferEmptyStream: AsyncStream<Bool>
    public let failedToPlayStream: AsyncStream<PlayerHostError?>

    private var statusObservation: NSKeyValueObservation?
    private var readyForDisplayObservation: NSKeyValueObservation?
    private var bufferEmptyObservation: NSKeyValueObservation?
    private var failedObserver: NSObjectProtocol?

    public override init() {
        self.player = AVPlayer()
        self.controller = PlayerHostingController()
        self.controller.player = player

        var statusCont: AsyncStream<Int>.Continuation!
        self.statusStream = AsyncStream { statusCont = $0 }
        var readyCont: AsyncStream<Bool>.Continuation!
        self.readyForDisplayStream = AsyncStream { readyCont = $0 }
        var bufferCont: AsyncStream<Bool>.Continuation!
        self.bufferEmptyStream = AsyncStream { bufferCont = $0 }
        var failedCont: AsyncStream<PlayerHostError?>.Continuation!
        self.failedToPlayStream = AsyncStream { failedCont = $0 }

        super.init()

        self.statusContinuation = statusCont
        self.readyForDisplayContinuation = readyCont
        self.bufferEmptyContinuation = bufferCont
        self.failedToPlayContinuation = failedCont

        // KVO on AVPlayer.currentItem.status — set up once; we rebind the
        // observation each time replaceItem swaps the item.
        observeReadyForDisplay()
    }

    public func replaceItem(url: URL) {
        statusObservation?.invalidate()
        bufferEmptyObservation?.invalidate()
        if let failedObserver {
            NotificationCenter.default.removeObserver(failedObserver)
            self.failedObserver = nil
        }

        let item = AVPlayerItem(url: url)
        // Reduce initial buffering to ~2s so the first frame appears quickly.
        // Keep automaticallyWaitsToMinimizeStalling at its default (true) —
        // changing it to false conflicts with the bufferEmpty reconnect logic.
        item.preferredForwardBufferDuration = 2.0
        player.replaceCurrentItem(with: item)

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            Task { @MainActor in
                self.statusContinuation?.yield(item.status.rawValue)
            }
        }
        bufferEmptyObservation = item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            Task { @MainActor in
                self.bufferEmptyContinuation?.yield(item.isPlaybackBufferEmpty)
            }
        }
        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let underlying = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            let wrapped = underlying.map { PlayerHostError($0) }
            Task { @MainActor in
                self.failedToPlayContinuation?.yield(wrapped)
            }
        }

        player.play()
    }

    public func tearDown() {
        statusObservation?.invalidate()
        statusObservation = nil
        readyForDisplayObservation?.invalidate()
        readyForDisplayObservation = nil
        bufferEmptyObservation?.invalidate()
        bufferEmptyObservation = nil
        if let failedObserver {
            NotificationCenter.default.removeObserver(failedObserver)
            self.failedObserver = nil
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
        controller.player = nil
        statusContinuation?.finish()
        readyForDisplayContinuation?.finish()
        bufferEmptyContinuation?.finish()
        failedToPlayContinuation?.finish()
    }

    private func observeReadyForDisplay() {
        // Watch the AVPlayerViewController-owned layer's readyForDisplay.
        // The controller exposes the layer indirectly; the cleanest hook is
        // KVO on contentOverlayView.layer? — but simpler: poll once via
        // statusStream's .readyToPlay AND a follow-up from
        // AVPlayer.timeControlStatus, which transitions to .playing once the
        // first frame renders.
        readyForDisplayObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self else { return }
            // .playing means the player is actually rendering frames.
            let isPlaying = player.timeControlStatus == .playing
            Task { @MainActor in
                self.readyForDisplayContinuation?.yield(isPlaying)
            }
        }
    }
}

#endif
