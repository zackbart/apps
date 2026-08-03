import Foundation

public struct BaseItemDto: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let type: String?
    public let serverId: String?
    public let parentId: String?
    public let imageTags: [String: String]?
    public let backdropImageTags: [String]?
    public let overview: String?
    public let productionYear: Int?
    public let userData: UserItemDataDto?
    public let runTimeTicks: Int64?
    public let seriesName: String?
    public let seasonName: String?
    public let indexNumber: Int?
    public let communityRating: Double?

    public init(
        id: String,
        name: String,
        type: String? = nil,
        serverId: String? = nil,
        parentId: String? = nil,
        imageTags: [String: String]? = nil,
        backdropImageTags: [String]? = nil,
        overview: String? = nil,
        productionYear: Int? = nil,
        userData: UserItemDataDto? = nil,
        runTimeTicks: Int64? = nil,
        seriesName: String? = nil,
        seasonName: String? = nil,
        indexNumber: Int? = nil,
        communityRating: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.serverId = serverId
        self.parentId = parentId
        self.imageTags = imageTags
        self.backdropImageTags = backdropImageTags
        self.overview = overview
        self.productionYear = productionYear
        self.userData = userData
        self.runTimeTicks = runTimeTicks
        self.seriesName = seriesName
        self.seasonName = seasonName
        self.indexNumber = indexNumber
        self.communityRating = communityRating
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case serverId = "ServerId"
        case parentId = "ParentId"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
        case overview = "Overview"
        case productionYear = "ProductionYear"
        case userData = "UserData"
        case runTimeTicks = "RunTimeTicks"
        case seriesName = "SeriesName"
        case seasonName = "SeasonName"
        case indexNumber = "IndexNumber"
        case communityRating = "CommunityRating"
    }
}

public struct BaseItemDtoQueryResult: Decodable, Sendable, Equatable {
    public let items: [BaseItemDto]
    public let totalRecordCount: Int?

    public init(items: [BaseItemDto], totalRecordCount: Int? = nil) {
        self.items = items
        self.totalRecordCount = totalRecordCount
    }

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}