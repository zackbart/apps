import Foundation

public struct QuickConnectResult: Decodable, Sendable, Equatable {
    public let authenticated: Bool
    public let secret: String
    public let code: String
    public let deviceId: String?
    public let deviceName: String?
    public let appName: String?
    public let appVersion: String?
    public let dateAdded: Date?

    public init(
        authenticated: Bool,
        secret: String,
        code: String,
        deviceId: String? = nil,
        deviceName: String? = nil,
        appName: String? = nil,
        appVersion: String? = nil,
        dateAdded: Date? = nil
    ) {
        self.authenticated = authenticated
        self.secret = secret
        self.code = code
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.appName = appName
        self.appVersion = appVersion
        self.dateAdded = dateAdded
    }

    enum CodingKeys: String, CodingKey {
        case authenticated = "Authenticated"
        case secret = "Secret"
        case code = "Code"
        case deviceId = "DeviceId"
        case deviceName = "DeviceName"
        case appName = "AppName"
        case appVersion = "AppVersion"
        case dateAdded = "DateAdded"
    }
}
