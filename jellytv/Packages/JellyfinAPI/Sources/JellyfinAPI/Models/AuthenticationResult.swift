public struct AuthenticationResult: Decodable, Sendable, Equatable {
    public let user: UserDto
    public let sessionInfo: SessionInfoDto?
    public let accessToken: String
    public let serverId: String

    public init(
        user: UserDto,
        sessionInfo: SessionInfoDto? = nil,
        accessToken: String,
        serverId: String
    ) {
        self.user = user
        self.sessionInfo = sessionInfo
        self.accessToken = accessToken
        self.serverId = serverId
    }

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case sessionInfo = "SessionInfo"
        case accessToken = "AccessToken"
        case serverId = "ServerId"
    }
}
