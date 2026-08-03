#if os(tvOS)
import UIKit
import AVKit
import AVFoundation

/// Custom `AVPlayerViewController` subclass that:
/// - Enables Picture-in-Picture (`allowsPictureInPicturePlayback = true`).
/// - Sets `AVAudioSession` category to `.playback` on appear and restores the
///   prior category on disappear, so PiP can suspend/resume cleanly without
///   permanently changing the app-wide session state.
/// - Intercepts `.upArrow` and `.downArrow` Siri Remote presses for in-player
///   channel up/down. We deliberately do NOT call `super.pressesBegan` for
///   those two keys (otherwise AVPlayerViewController fires its own info
///   overlay simultaneously with our channel change). All other presses
///   (Menu, Select, Play/Pause, etc.) are forwarded to `super`.
/// - Adds vertical-swipe gesture recognizers as a second input affordance.
final class PlayerHostingController: AVPlayerViewController {
    var onChannelUp: (() -> Void)?
    var onChannelDown: (() -> Void)?
    /// Called when the user presses the Menu button, before the press is
    /// forwarded to `super` (which dismisses the AVPlayerViewController).
    /// Wire this to `PlayerViewModel.dismiss()` + the SwiftUI `onDismiss`
    /// callback so the live stream is torn down before the view disappears.
    var onDismissRequested: (() -> Void)?

    private var priorAudioSessionCategory: AVAudioSession.Category?

    override func viewDidLoad() {
        super.viewDidLoad()
        allowsPictureInPicturePlayback = true

        let upSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
        upSwipe.direction = .up
        view.addGestureRecognizer(upSwipe)

        let downSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        downSwipe.direction = .down
        view.addGestureRecognizer(downSwipe)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let session = AVAudioSession.sharedInstance()
        priorAudioSessionCategory = session.category
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let session = AVAudioSession.sharedInstance()
        if let prior = priorAudioSessionCategory {
            try? session.setCategory(prior)
        }
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Filter out up/down arrow presses we want to handle ourselves —
        // forward everything else to super so Menu/Select/Play-Pause still
        // work normally.
        var handled: Set<UIPress> = []
        for press in presses {
            switch press.type {
            case .upArrow:
                onChannelUp?()
                handled.insert(press)
            case .downArrow:
                onChannelDown?()
                handled.insert(press)
            case .menu:
                // Initiate teardown BEFORE forwarding to super so the stream
                // closes before AVPlayerViewController dismisses the view.
                onDismissRequested?()
            default:
                break
            }
        }
        let forwarded = presses.subtracting(handled)
        if !forwarded.isEmpty {
            super.pressesBegan(forwarded, with: event)
        }
    }

    @objc private func handleSwipeUp() { onChannelUp?() }
    @objc private func handleSwipeDown() { onChannelDown?() }
}
#endif
