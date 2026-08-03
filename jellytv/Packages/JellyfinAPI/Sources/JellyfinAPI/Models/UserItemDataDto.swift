import Foundation

public struct UserItemDataDto: Decodable, Sendable, Equatable {
    public let playbackPositionTicks: Int64?
    public let played: Bool?
    public let playedPercentage: Double?
    public let isFavorite: Bool?
    public let like: Bool?
    public let lastPlayedDate: Date?
    public let playCount: Int?
    public let repeatMode: String?

    public init(
        playbackPositionTicks: Int64? = nil,
        played: Bool? = nil,
        playedPercentage: Double? = nil,
        isFavorite: Bool? = nil,
        like: Bool? = nil,
        lastPlayedDate: Date? = nil,
        playCount: Int? = nil,
        repeatMode: String? = nil
    ) {
        self.playbackPositionTicks = playbackPositionTicks
        self.played = played
        self.playedPercentage = playedPercentage
        self.isFavorite = isFavorite
        self.like = like
        self.lastPlayedDate = lastPlayedDate
        self.playCount = playCount
        self.repeatMode = repeatMode
    }

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case played = "Played"
        case playedPercentage = "PlayedPercentage"
        case isFavorite = "IsFavorite"
        case like = "Like"
        case lastPlayedDate = "LastPlayedDate"
        case playCount = "PlayCount"
        case repeatMode = "RepeatMode"
    }
}