import Foundation

/// `/LiveTv/SeriesTimers` entry — a recurring (series) recording rule.
public struct SeriesTimerInfoDto: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let serverId: String?
    public let channelId: String?
    public let channelName: String?
    public let channelPrimaryImageTag: String?
    public let programId: String?
    public let name: String?
    public let overview: String?
    public let startDate: Date?
    public let endDate: Date?
    public let serviceName: String?
    public let priority: Int?
    public let prePaddingSeconds: Int?
    public let postPaddingSeconds: Int?
    public let recordAnyTime: Bool?
    public let recordAnyChannel: Bool?
    public let recordNewOnly: Bool?
    public let skipEpisodesInLibrary: Bool?
    public let keepUpTo: Int?
    public let days: [String]?

    public init(
        id: String,
        serverId: String? = nil,
        channelId: String? = nil,
        channelName: String? = nil,
        channelPrimaryImageTag: String? = nil,
        programId: String? = nil,
        name: String? = nil,
        overview: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        serviceName: String? = nil,
        priority: Int? = nil,
        prePaddingSeconds: Int? = nil,
        postPaddingSeconds: Int? = nil,
        recordAnyTime: Bool? = nil,
        recordAnyChannel: Bool? = nil,
        recordNewOnly: Bool? = nil,
        skipEpisodesInLibrary: Bool? = nil,
        keepUpTo: Int? = nil,
        days: [String]? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.channelId = channelId
        self.channelName = channelName
        self.channelPrimaryImageTag = channelPrimaryImageTag
        self.programId = programId
        self.name = name
        self.overview = overview
        self.startDate = startDate
        self.endDate = endDate
        self.serviceName = serviceName
        self.priority = priority
        self.prePaddingSeconds = prePaddingSeconds
        self.postPaddingSeconds = postPaddingSeconds
        self.recordAnyTime = recordAnyTime
        self.recordAnyChannel = recordAnyChannel
        self.recordNewOnly = recordNewOnly
        self.skipEpisodesInLibrary = skipEpisodesInLibrary
        self.keepUpTo = keepUpTo
        self.days = days
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case serverId = "ServerId"
        case channelId = "ChannelId"
        case channelName = "ChannelName"
        case channelPrimaryImageTag = "ChannelPrimaryImageTag"
        case programId = "ProgramId"
        case name = "Name"
        case overview = "Overview"
        case startDate = "StartDate"
        case endDate = "EndDate"
        case serviceName = "ServiceName"
        case priority = "Priority"
        case prePaddingSeconds = "PrePaddingSeconds"
        case postPaddingSeconds = "PostPaddingSeconds"
        case recordAnyTime = "RecordAnyTime"
        case recordAnyChannel = "RecordAnyChannel"
        case recordNewOnly = "RecordNewOnly"
        case skipEpisodesInLibrary = "SkipEpisodesInLibrary"
        case keepUpTo = "KeepUpTo"
        case days = "Days"
    }
}

public struct SeriesTimerInfoDtoQueryResult: Decodable, Sendable, Equatable {
    public let items: [SeriesTimerInfoDto]
    public let totalRecordCount: Int?

    public init(items: [SeriesTimerInfoDto], totalRecordCount: Int? = nil) {
        self.items = items
        self.totalRecordCount = totalRecordCount
    }

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}
