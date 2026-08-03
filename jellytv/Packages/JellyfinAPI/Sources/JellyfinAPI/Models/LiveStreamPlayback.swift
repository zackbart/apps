import Foundation

/// Resolved playback information for a live stream. The actor builds the
/// playback URL with auth baked in so callers never see the access token.
public struct LiveStreamPlayback: Sendable, Equatable {
    public let playbackURL: URL
    public let liveStreamId: String?

    public init(playbackURL: URL, liveStreamId: String? = nil) {
        self.playbackURL = playbackURL
        self.liveStreamId = liveStreamId
    }
}
