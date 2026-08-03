import Foundation

public struct UserDto: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let serverId: String?
    public let primaryImageTag: String?
    public let hasPassword: Bool?
    public let hasConfiguredPassword: Bool?
    public let lastLoginDate: Date?
    public let lastActivityDate: Date?

    public init(
        id: String,
        name: String,
        serverId: String? = nil,
        primaryImageTag: String? = nil,
        hasPassword: Bool? = nil,
        hasConfiguredPassword: Bool? = nil,
        lastLoginDate: Date? = nil,
        lastActivityDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.serverId = serverId
        self.primaryImageTag = primaryImageTag
        self.hasPassword = hasPassword
        self.hasConfiguredPassword = hasConfiguredPassword
        self.lastLoginDate = lastLoginDate
        self.lastActivityDate = lastActivityDate
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case serverId = "ServerId"
        case primaryImageTag = "PrimaryImageTag"
        case hasPassword = "HasPassword"
        case hasConfiguredPassword = "HasConfiguredPassword"
        case lastLoginDate = "LastLoginDate"
        case lastActivityDate = "LastActivityDate"
    }
}
