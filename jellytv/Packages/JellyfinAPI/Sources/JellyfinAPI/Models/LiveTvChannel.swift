import Foundation

public struct LiveTvChannel: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let number: String?
    public let channelType: String?
    public let serverId: String?
    public let imageTags: [String: String]?
    public let userData: UserItemDataDto?
    /// The program currently airing on this channel. Server populates this
    /// when `addCurrentProgram=true` is sent on `/LiveTv/Channels`.
    public let currentProgram: LiveTvProgram?

    public init(
        id: String,
        name: String,
        number: String? = nil,
        channelType: String? = nil,
        serverId: String? = nil,
        imageTags: [String: String]? = nil,
        userData: UserItemDataDto? = nil,
        currentProgram: LiveTvProgram? = nil
    ) {
        self.id = id
        self.name = name
        self.number = number
        self.channelType = channelType
        self.serverId = serverId
        self.imageTags = imageTags
        self.userData = userData
        self.currentProgram = currentProgram
    }

    /// Convenience: tag for the channel's primary image, used to build the
    /// channel logo URL.
    public var primaryImageTag: String? { imageTags?["Primary"] }

    public var isFavorite: Bool { userData?.isFavorite ?? false }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case number = "Number"
        case channelType = "ChannelType"
        case serverId = "ServerId"
        case imageTags = "ImageTags"
        case userData = "UserData"
        case currentProgram = "CurrentProgram"
    }
}

public struct LiveTvChannelQueryResult: Decodable, Sendable, Equatable {
    public let items: [LiveTvChannel]
    public let totalRecordCount: Int?

    public init(items: [LiveTvChannel], totalRecordCount: Int? = nil) {
        self.items = items
        self.totalRecordCount = totalRecordCount
    }

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}
