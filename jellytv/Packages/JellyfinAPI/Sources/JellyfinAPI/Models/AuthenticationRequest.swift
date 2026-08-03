public struct AuthenticationRequest: Encodable, Sendable {
    public let username: String
    public let pw: String

    public init(username: String, pw: String) {
        self.username = username
        self.pw = pw
    }

    enum CodingKeys: String, CodingKey {
        case username = "Username"
        case pw = "Pw"
    }
}
