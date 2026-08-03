public struct PublicSystemInfo: Decodable, Sendable, Equatable {
    public let serverName: String?
    public let version: String?
    public let id: String?
    public let productName: String?
    public let localAddress: String?
    public let startupWizardCompleted: Bool?

    public init(
        serverName: String? = nil,
        version: String? = nil,
        id: String? = nil,
        productName: String? = nil,
        localAddress: String? = nil,
        startupWizardCompleted: Bool? = nil
    ) {
        self.serverName = serverName
        self.version = version
        self.id = id
        self.productName = productName
        self.localAddress = localAddress
        self.startupWizardCompleted = startupWizardCompleted
    }

    enum CodingKeys: String, CodingKey {
        case serverName = "ServerName"
        case version = "Version"
        case id = "Id"
        case productName = "ProductName"
        case localAddress = "LocalAddress"
        case startupWizardCompleted = "StartupWizardCompleted"
    }
}
