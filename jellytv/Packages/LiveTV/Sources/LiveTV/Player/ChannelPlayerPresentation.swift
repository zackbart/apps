import SwiftUI
import JellyfinAPI

/// Presents `LiveTVPlayerView` full-screen on tvOS (as a `fullScreenCover`)
/// and as a sheet on macOS so the LiveTV package compiles cleanly for both
/// platforms. Centralized here so any view that surfaces channels can wire
/// the same playback path simply by binding `selectedChannel`.
///
/// Phase D widening: the `openStream` closure now returns `LiveStreamPlayback`
/// (id + URL) so the player can call `/LiveStreams/Close` on dismiss. Adds
/// `closeStream`, `channels` (for in-player channel up/down), an optional
/// `program` for the splash/HUD on the program-detail entry, and a
/// `lastWatchedChannelId` binding for focus restoration after dismiss.
public struct ChannelPlayerPresentation: ViewModifier {
    @Binding var selectedChannel: LiveTvChannel?
    let channels: [LiveTvChannel]
    let serverURL: URL
    let program: LiveTvProgram?
    let openStream: @Sendable (LiveTvChannel, _ forceTranscoding: Bool) async throws -> LiveStreamPlayback
    let closeStream: @Sendable (String) async -> Void
    @Binding var lastWatchedChannelId: String?

    public init(
        selectedChannel: Binding<LiveTvChannel?>,
        channels: [LiveTvChannel],
        serverURL: URL,
        program: LiveTvProgram? = nil,
        openStream: @escaping @Sendable (LiveTvChannel, Bool) async throws -> LiveStreamPlayback,
        closeStream: @escaping @Sendable (String) async -> Void,
        lastWatchedChannelId: Binding<String?>
    ) {
        self._selectedChannel = selectedChannel
        self.channels = channels
        self.serverURL = serverURL
        self.program = program
        self.openStream = openStream
        self.closeStream = closeStream
        self._lastWatchedChannelId = lastWatchedChannelId
    }

    public func body(content: Content) -> some View {
        #if os(tvOS)
        content.fullScreenCover(item: $selectedChannel) { channel in
            playerView(for: channel)
        }
        #else
        content.sheet(item: $selectedChannel) { channel in
            playerView(for: channel)
        }
        #endif
    }

    private func playerView(for channel: LiveTvChannel) -> some View {
        LiveTVPlayerView(
            initialChannel: channel,
            channels: channels,
            serverURL: serverURL,
            initialProgram: program ?? channel.currentProgram,
            openStream: openStream,
            closeStream: closeStream,
            onDismiss: { selectedChannel = nil },
            onChannelChanged: { newChannel in
                lastWatchedChannelId = newChannel.id
            }
        )
    }
}
