import Foundation

/// Filters for `GET /LiveTv/Channels`. All fields are optional; nil means
/// "no constraint." Mirrors the Jellyfin filter parameters.
public struct LiveTvChannelFilters: Sendable, Equatable {
    public var isMovie: Bool?
    public var isSeries: Bool?
    public var isNews: Bool?
    public var isKids: Bool?
    public var isSports: Bool?
    public var isFavorite: Bool?
    /// When set, only channels whose program currently airing matches this filter.
    public var isAiringNow: Bool?
    public var sortBy: String?
    public var sortOrder: String?
    public var startIndex: Int?
    public var limit: Int?

    public init(
        isMovie: Bool? = nil,
        isSeries: Bool? = nil,
        isNews: Bool? = nil,
        isKids: Bool? = nil,
        isSports: Bool? = nil,
        isFavorite: Bool? = nil,
        isAiringNow: Bool? = nil,
        sortBy: String? = "SortName",
        sortOrder: String? = "Ascending",
        startIndex: Int? = nil,
        limit: Int? = nil
    ) {
        self.isMovie = isMovie
        self.isSeries = isSeries
        self.isNews = isNews
        self.isKids = isKids
        self.isSports = isSports
        self.isFavorite = isFavorite
        self.isAiringNow = isAiringNow
        self.sortBy = sortBy
        self.sortOrder = sortOrder
        self.startIndex = startIndex
        self.limit = limit
    }

    public static let `default` = LiveTvChannelFilters()
    public static let favorites = LiveTvChannelFilters(isFavorite: true)
    public static let movies = LiveTvChannelFilters(isMovie: true)
    public static let sports = LiveTvChannelFilters(isSports: true)
    public static let news = LiveTvChannelFilters(isNews: true)
    public static let kids = LiveTvChannelFilters(isKids: true)
}

/// Filters for `GET /LiveTv/Programs` and `/LiveTv/Programs/Recommended`.
public struct LiveTvProgramFilters: Sendable, Equatable {
    public var isAiring: Bool?
    public var hasAired: Bool?
    public var isMovie: Bool?
    public var isSeries: Bool?
    public var isNews: Bool?
    public var isKids: Bool?
    public var isSports: Bool?
    public var genres: [String]?
    public var sortBy: [String]?
    public var sortOrder: String?
    public var limit: Int?

    public init(
        isAiring: Bool? = nil,
        hasAired: Bool? = nil,
        isMovie: Bool? = nil,
        isSeries: Bool? = nil,
        isNews: Bool? = nil,
        isKids: Bool? = nil,
        isSports: Bool? = nil,
        genres: [String]? = nil,
        sortBy: [String]? = nil,
        sortOrder: String? = nil,
        limit: Int? = nil
    ) {
        self.isAiring = isAiring
        self.hasAired = hasAired
        self.isMovie = isMovie
        self.isSeries = isSeries
        self.isNews = isNews
        self.isKids = isKids
        self.isSports = isSports
        self.genres = genres
        self.sortBy = sortBy
        self.sortOrder = sortOrder
        self.limit = limit
    }
}
