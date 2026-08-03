import Foundation

public struct LiveTvProgram: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let channelId: String?
    public let channelName: String?
    public let channelNumber: String?
    public let channelPrimaryImageTag: String?
    public let overview: String?
    public let startDate: Date?
    public let endDate: Date?
    public let isLive: Bool?
    public let isNews: Bool?
    public let isSports: Bool?
    public let isKids: Bool?
    public let isMovie: Bool?
    public let isSeries: Bool?
    public let isRepeat: Bool?
    public let isPremiere: Bool?
    public let episodeTitle: String?
    public let seriesName: String?
    public let productionYear: Int?
    public let genres: [String]?
    public let communityRating: Double?
    public let officialRating: String?
    public let imageTags: [String: String]?
    public let runTimeTicks: Int64?

    public init(
        id: String,
        name: String,
        channelId: String? = nil,
        channelName: String? = nil,
        channelNumber: String? = nil,
        channelPrimaryImageTag: String? = nil,
        overview: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isLive: Bool? = nil,
        isNews: Bool? = nil,
        isSports: Bool? = nil,
        isKids: Bool? = nil,
        isMovie: Bool? = nil,
        isSeries: Bool? = nil,
        isRepeat: Bool? = nil,
        isPremiere: Bool? = nil,
        episodeTitle: String? = nil,
        seriesName: String? = nil,
        productionYear: Int? = nil,
        genres: [String]? = nil,
        communityRating: Double? = nil,
        officialRating: String? = nil,
        imageTags: [String: String]? = nil,
        runTimeTicks: Int64? = nil
    ) {
        self.id = id
        self.name = name
        self.channelId = channelId
        self.channelName = channelName
        self.channelNumber = channelNumber
        self.channelPrimaryImageTag = channelPrimaryImageTag
        self.overview = overview
        self.startDate = startDate
        self.endDate = endDate
        self.isLive = isLive
        self.isNews = isNews
        self.isSports = isSports
        self.isKids = isKids
        self.isMovie = isMovie
        self.isSeries = isSeries
        self.isRepeat = isRepeat
        self.isPremiere = isPremiere
        self.episodeTitle = episodeTitle
        self.seriesName = seriesName
        self.productionYear = productionYear
        self.genres = genres
        self.communityRating = communityRating
        self.officialRating = officialRating
        self.imageTags = imageTags
        self.runTimeTicks = runTimeTicks
    }

    public var primaryImageTag: String? { imageTags?["Primary"] }
    public var thumbImageTag: String? { imageTags?["Thumb"] }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case channelId = "ChannelId"
        case channelName = "ChannelName"
        case channelNumber = "ChannelNumber"
        case channelPrimaryImageTag = "ChannelPrimaryImageTag"
        case overview = "Overview"
        case startDate = "StartDate"
        case endDate = "EndDate"
        case isLive = "IsLive"
        case isNews = "IsNews"
        case isSports = "IsSports"
        case isKids = "IsKids"
        case isMovie = "IsMovie"
        case isSeries = "IsSeries"
        case isRepeat = "IsRepeat"
        case isPremiere = "IsPremiere"
        case episodeTitle = "EpisodeTitle"
        case seriesName = "SeriesName"
        case productionYear = "ProductionYear"
        case genres = "Genres"
        case communityRating = "CommunityRating"
        case officialRating = "OfficialRating"
        case imageTags = "ImageTags"
        case runTimeTicks = "RunTimeTicks"
    }
}

public struct LiveTvProgramQueryResult: Decodable, Sendable, Equatable {
    public let items: [LiveTvProgram]
    public let totalRecordCount: Int?

    public init(items: [LiveTvProgram], totalRecordCount: Int? = nil) {
        self.items = items
        self.totalRecordCount = totalRecordCount
    }

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}
