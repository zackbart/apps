import Foundation

public struct MediaSourceInfo: Decodable, Sendable, Equatable {
    public let id: String?
    public let path: String?
    public let transcodingUrl: String?
    public let container: String?
    public let liveStreamId: String?
    public let supportsTranscoding: Bool?

    public init(
        id: String? = nil,
        path: String? = nil,
        transcodingUrl: String? = nil,
        container: String? = nil,
        liveStreamId: String? = nil,
        supportsTranscoding: Bool? = nil
    ) {
        self.id = id
        self.path = path
        self.transcodingUrl = transcodingUrl
        self.container = container
        self.liveStreamId = liveStreamId
        self.supportsTranscoding = supportsTranscoding
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case path = "Path"
        case transcodingUrl = "TranscodingUrl"
        case container = "Container"
        case liveStreamId = "LiveStreamId"
        case supportsTranscoding = "SupportsTranscoding"
    }
}

/// Response from `POST /LiveTv/LiveStreams/Open`. Different Jellyfin versions
/// return either a singular `MediaSource` or a plural `MediaSources` array,
/// so we decode both and expose `primary` for callers.
public struct LiveStreamResponse: Decodable, Sendable, Equatable {
    public let mediaSource: MediaSourceInfo?
    public let mediaSources: [MediaSourceInfo]?

    public init(mediaSource: MediaSourceInfo? = nil, mediaSources: [MediaSourceInfo]? = nil) {
        self.mediaSource = mediaSource
        self.mediaSources = mediaSources
    }

    public var primary: MediaSourceInfo? {
        mediaSource ?? mediaSources?.first
    }

    enum CodingKeys: String, CodingKey {
        case mediaSource = "MediaSource"
        case mediaSources = "MediaSources"
    }
}
