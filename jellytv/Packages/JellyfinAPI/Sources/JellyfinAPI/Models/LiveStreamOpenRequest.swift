import Foundation

/// Request body for `POST /LiveTv/LiveStreams/Open`. Encode-only.
/// (Currently unused — `liveTvOpenStream` switched to PlaybackInfo, see
/// `PlaybackInfoBody`. Kept here in case we need the lower-level endpoint.)
public struct LiveStreamOpenRequest: Encodable, Sendable {
    public let openToken: String
    public let deviceProfile: DeviceProfileBody

    public init(openToken: String, deviceProfile: DeviceProfileBody) {
        self.openToken = openToken
        self.deviceProfile = deviceProfile
    }

    enum CodingKeys: String, CodingKey {
        case openToken = "OpenToken"
        case deviceProfile = "DeviceProfile"
    }
}

/// Request body for `POST /Items/{itemId}/PlaybackInfo`. Encode-only.
public struct PlaybackInfoBody: Encodable, Sendable {
    public let deviceProfile: DeviceProfileBody

    public init(deviceProfile: DeviceProfileBody) {
        self.deviceProfile = deviceProfile
    }

    enum CodingKeys: String, CodingKey {
        case deviceProfile = "DeviceProfile"
    }
}

public struct DeviceProfileBody: Encodable, Sendable {
    public let name: String
    public let maxStreamingBitrate: Int
    public let maxStaticBitrate: Int
    public let directPlayProfiles: [DirectPlayProfileBody]
    public let transcodingProfiles: [TranscodingProfileBody]

    public init(
        name: String,
        maxStreamingBitrate: Int,
        maxStaticBitrate: Int,
        directPlayProfiles: [DirectPlayProfileBody],
        transcodingProfiles: [TranscodingProfileBody]
    ) {
        self.name = name
        self.maxStreamingBitrate = maxStreamingBitrate
        self.maxStaticBitrate = maxStaticBitrate
        self.directPlayProfiles = directPlayProfiles
        self.transcodingProfiles = transcodingProfiles
    }

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case maxStreamingBitrate = "MaxStreamingBitrate"
        case maxStaticBitrate = "MaxStaticBitrate"
        case directPlayProfiles = "DirectPlayProfiles"
        case transcodingProfiles = "TranscodingProfiles"
    }

    /// Minimum-viable profile for tvOS Live TV. DirectPlay covers MPEG-TS
    /// (HDHomeRun's native container) plus common Jellyfin formats. The HLS
    /// transcode profile uses container=ts with BreakOnNonKeyFrames so the
    /// server emits a real `master.m3u8` URL natively for live TV — matching
    /// Jellyfin's web client live-TV profile.
    public static let liveTvDefault = DeviceProfileBody(
        name: "JellyTV",
        maxStreamingBitrate: 120_000_000,
        maxStaticBitrate: 100_000_000,
        directPlayProfiles: [
            DirectPlayProfileBody(
                container: "ts,m2ts,mkv,mp4,m4v,mov",
                type: "Video",
                videoCodec: "h264,hevc",
                audioCodec: "aac,ac3,eac3,mp3"
            ),
        ],
        transcodingProfiles: [
            TranscodingProfileBody(
                container: "ts",
                type: "Video",
                videoCodec: "h264,hevc",
                audioCodec: "aac,mp3,ac3,eac3",
                protocol: "hls",
                context: "Streaming",
                minSegments: 1,
                breakOnNonKeyFrames: true
            ),
        ]
    )
}

public struct DirectPlayProfileBody: Encodable, Sendable {
    public let container: String
    public let type: String
    public let videoCodec: String?
    public let audioCodec: String?

    public init(container: String, type: String, videoCodec: String? = nil, audioCodec: String? = nil) {
        self.container = container
        self.type = type
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
    }

    enum CodingKeys: String, CodingKey {
        case container = "Container"
        case type = "Type"
        case videoCodec = "VideoCodec"
        case audioCodec = "AudioCodec"
    }
}

public struct TranscodingProfileBody: Encodable, Sendable {
    public let container: String
    public let type: String
    public let videoCodec: String
    public let audioCodec: String
    public let `protocol`: String
    public let context: String
    public let minSegments: Int
    public let breakOnNonKeyFrames: Bool

    public init(
        container: String,
        type: String,
        videoCodec: String,
        audioCodec: String,
        protocol: String,
        context: String,
        minSegments: Int,
        breakOnNonKeyFrames: Bool
    ) {
        self.container = container
        self.type = type
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.`protocol` = `protocol`
        self.context = context
        self.minSegments = minSegments
        self.breakOnNonKeyFrames = breakOnNonKeyFrames
    }

    enum CodingKeys: String, CodingKey {
        case container = "Container"
        case type = "Type"
        case videoCodec = "VideoCodec"
        case audioCodec = "AudioCodec"
        case `protocol` = "Protocol"
        case context = "Context"
        case minSegments = "MinSegments"
        case breakOnNonKeyFrames = "BreakOnNonKeyFrames"
    }
}
