public struct SessionInfoDto: Decodable, Sendable, Equatable {
    public let id: String?
    public let userId: String?
    public let userName: String?
    public let deviceId: String?
    public let deviceName: String?

    public init(
        id: String? = nil,
        userId: String? = nil,
        userName: String? = nil,
        deviceId: String? = nil,
        deviceName: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.deviceId = deviceId
        self.deviceName = deviceName
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case userId = "UserId"
        case userName = "UserName"
        case deviceId = "DeviceId"
        case deviceName = "DeviceName"
    }
}
