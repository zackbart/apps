public struct QuickConnectAuthRequest: Encodable, Sendable {
    public let secret: String

    public init(secret: String) {
        self.secret = secret
    }

    enum CodingKeys: String, CodingKey {
        case secret = "Secret"
    }
}
