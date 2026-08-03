import SwiftUI
import AVFoundation
import AppKit

/// Lightweight in-app video preview backed by the shared `VideoPreviewPool`.
///
/// Renders a muted, looping `AVPlayerLayer` scaled to fill its SwiftUI frame.
/// Players are pooled across cards and detail views, so hovering across a grid
/// doesn't churn the decode pipeline.
struct VideoPreviewPlayer: NSViewRepresentable {
    let wallpaperID: String
    let url: URL
    var isPlaying: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(wallpaperID: wallpaperID)
    }

    func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.wantsLayer = true
        view.layer = CALayer()
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.layer?.masksToBounds = true
        let playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(playerLayer)
        view.playerLayer = playerLayer
        return view
    }

    func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        context.coordinator.wallpaperID = wallpaperID
        if isPlaying {
            let player = VideoPreviewPool.shared.player(for: wallpaperID, url: url)
            if nsView.playerLayer?.player !== player {
                nsView.playerLayer?.player = player
            }
            player.play()
        } else {
            VideoPreviewPool.shared.pause(id: wallpaperID)
        }
    }

    static func dismantleNSView(_ nsView: PlayerContainerView, coordinator: Coordinator) {
        nsView.playerLayer?.player = nil
        let id = coordinator.wallpaperID
        Task { @MainActor in
            VideoPreviewPool.shared.release(id: id)
        }
    }

    final class Coordinator {
        var wallpaperID: String
        init(wallpaperID: String) { self.wallpaperID = wallpaperID }
    }

    final class PlayerContainerView: NSView {
        var playerLayer: AVPlayerLayer?

        override func layout() {
            super.layout()
            playerLayer?.frame = bounds
        }
    }
}
