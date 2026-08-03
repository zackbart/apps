import Foundation
import JellyfinAPI

/// The fully-loaded EPG snapshot powering `GuideView`.
public struct GuideContent: Equatable, Sendable {
    public let serverURL: URL
    public let windowStart: Date
    public let windowEnd: Date
    public let channels: [LiveTvChannel]
    /// Programs grouped by `channelId`. Channels with no programs in the
    /// window are absent from this dictionary (callers should fall back to an
    /// empty array via `programs(for:)`).
    public let programsByChannel: [String: [LiveTvProgram]]

    public init(
        serverURL: URL,
        windowStart: Date,
        windowEnd: Date,
        channels: [LiveTvChannel],
        programsByChannel: [String: [LiveTvProgram]]
    ) {
        self.serverURL = serverURL
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.channels = channels
        self.programsByChannel = programsByChannel
    }

    public func programs(for channelId: String) -> [LiveTvProgram] {
        programsByChannel[channelId] ?? []
    }

    public var isEmpty: Bool {
        channels.isEmpty
    }
}
