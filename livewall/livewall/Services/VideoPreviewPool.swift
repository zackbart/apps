import AVFoundation
import Foundation

/// Pooled AVPlayer manager for lightweight in-gallery video previews.
///
/// The pool caps the number of concurrent AVPlayer instances to avoid thrashing memory
/// and the decode pipeline when the user rapidly hovers across many wallpaper cards.
/// Players are keyed by wallpaper ID and evicted LRU-style when the cap is exceeded.
///
/// All access is main-actor isolated because AVPlayer / AVPlayerLayer must be
/// configured on the main thread.
@MainActor
final class VideoPreviewPool {
    static let shared = VideoPreviewPool()

    private let maxConcurrent = 2

    private struct Entry {
        let player: AVPlayer
        var loopObserver: NSObjectProtocol?
    }

    private var entries: [String: Entry] = [:]
    private var lruOrder: [String] = []

    private init() {}

    /// Returns a muted, looping AVPlayer for the given wallpaper.
    /// Reuses an existing player if one is already pooled for this id.
    func player(for id: String, url: URL) -> AVPlayer {
        if let existing = entries[id] {
            touch(id)
            return existing.player
        }

        // Evict LRU if at capacity.
        while entries.count >= maxConcurrent, let oldest = lruOrder.first {
            evict(id: oldest)
        }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false

        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        entries[id] = Entry(player: player, loopObserver: observer)
        lruOrder.append(id)
        return player
    }

    /// Marks the pooled player as a candidate for future eviction,
    /// but does not tear it down immediately — the next `player(for:url:)`
    /// call for a different id may evict it.
    func release(id: String) {
        guard let index = lruOrder.firstIndex(of: id) else { return }
        lruOrder.remove(at: index)
        lruOrder.insert(id, at: 0) // move to front of eviction queue
    }

    /// Stops playback for a given id without removing the entry from the pool.
    func pause(id: String) {
        entries[id]?.player.pause()
    }

    private func touch(_ id: String) {
        if let index = lruOrder.firstIndex(of: id) {
            lruOrder.remove(at: index)
        }
        lruOrder.append(id)
    }

    private func evict(id: String) {
        guard let entry = entries.removeValue(forKey: id) else { return }
        if let observer = entry.loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        entry.player.pause()
        entry.player.replaceCurrentItem(with: nil)
        lruOrder.removeAll { $0 == id }
    }
}
