import Foundation

/// `/LiveTv/Timers` entry — a one-shot scheduled recording.
public struct TimerInfoDto: Decodable, Sendable, Equatable, Identifiable {
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
    public let status: String?
    public let seriesTimerId: String?
    public let runTimeTicks: Int64?

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
        status: String? = nil,
        seriesTimerId: String? = nil,
        runTimeTicks: Int64? = nil
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
        self.status = status
        self.seriesTimerId = seriesTimerId
        self.runTimeTicks = runTimeTicks
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
        case status = "Status"
        case seriesTimerId = "SeriesTimerId"
        case runTimeTicks = "RunTimeTicks"
    }
}

public struct TimerInfoDtoQueryResult: Decodable, Sendable, Equatable {
    public let items: [TimerInfoDto]
    public let totalRecordCount: Int?

    public init(items: [TimerInfoDto], totalRecordCount: Int? = nil) {
        self.items = items
        self.totalRecordCount = totalRecordCount
    }

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}
