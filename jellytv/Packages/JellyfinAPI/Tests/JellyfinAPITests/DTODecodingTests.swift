import Testing
import Foundation
@testable import JellyfinAPI

@Suite("DTO Decoding")
struct DTODecodingTests {

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    @Test func decodesPublicSystemInfo() throws {
        let json = """
        {
            "ServerName": "My Jellyfin Server",
            "Version": "10.11.8",
            "Id": "abc123",
            "ProductName": "Jellyfin Server",
            "LocalAddress": "http://192.168.1.50:8096",
            "StartupWizardCompleted": true
        }
        """
        let data = try #require(json.data(using: .utf8))
        let info = try decoder.decode(PublicSystemInfo.self, from: data)
        #expect(info.serverName == "My Jellyfin Server")
        #expect(info.version == "10.11.8")
        #expect(info.id == "abc123")
        #expect(info.productName == "Jellyfin Server")
        #expect(info.localAddress == "http://192.168.1.50:8096")
        #expect(info.startupWizardCompleted == true)
    }

    @Test func decodesAuthenticationResult() throws {
        let json = """
        {
            "User": {
                "Id": "user-001",
                "Name": "alice",
                "ServerId": "srv-001",
                "HasPassword": true,
                "HasConfiguredPassword": true
            },
            "SessionInfo": {
                "Id": "session-001",
                "UserId": "user-001",
                "UserName": "alice",
                "DeviceId": "device-001",
                "DeviceName": "Apple TV"
            },
            "AccessToken": "tok-abc",
            "ServerId": "srv-001"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let result = try decoder.decode(AuthenticationResult.self, from: data)
        #expect(result.accessToken == "tok-abc")
        #expect(result.serverId == "srv-001")
        #expect(result.user.id == "user-001")
        #expect(result.user.name == "alice")
        #expect(result.sessionInfo?.deviceName == "Apple TV")
    }

    @Test func decodesQuickConnectResult() throws {
        let json = """
        {
            "Authenticated": false,
            "Secret": "secret-xyz",
            "Code": "ABC123",
            "DeviceId": "device-001",
            "DeviceName": "Apple TV",
            "AppName": "JellyTV",
            "AppVersion": "1.0"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let result = try decoder.decode(QuickConnectResult.self, from: data)
        #expect(result.authenticated == false)
        #expect(result.secret == "secret-xyz")
        #expect(result.code == "ABC123")
        #expect(result.deviceId == "device-001")
        #expect(result.appName == "JellyTV")
        #expect(result.dateAdded == nil)
    }

    @Test func decodesQuickConnectResultWithDateAdded() throws {
        let isoString = "2024-03-15T10:30:00.0000000Z"
        let json = """
        {
            "Authenticated": true,
            "Secret": "secret-xyz",
            "Code": "ABC123",
            "DateAdded": "\(isoString)"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let result = try decoder.decode(QuickConnectResult.self, from: data)
        #expect(result.authenticated == true)
        #expect(result.dateAdded != nil)

        // Verify the date round-trips through iso8601 correctly
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expectedDate = try #require(formatter.date(from: isoString))
        #expect(result.dateAdded == expectedDate)
    }

    @Test func decodesProblemDetails() throws {
        let json = """
        {
            "type": "about:blank",
            "title": "Bad Request",
            "status": 400,
            "detail": "Missing field"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let problem = try decoder.decode(ProblemDetails.self, from: data)
        #expect(problem.type == "about:blank")
        #expect(problem.title == "Bad Request")
        #expect(problem.status == 400)
        #expect(problem.detail == "Missing field")
        #expect(problem.instance == nil)
    }

    @Test func encodesAuthenticationRequestWithPwField() throws {
        let request = AuthenticationRequest(username: "alice", pw: "secret")
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let dict = try JSONDecoder().decode([String: String].self, from: data)
        #expect(dict["Pw"] == "secret")
        #expect(dict["Username"] == "alice")
        #expect(dict["Password"] == nil)
    }

    @Test func encodesQuickConnectAuthRequest() throws {
        let request = QuickConnectAuthRequest(secret: "abc-secret")
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let dict = try JSONDecoder().decode([String: String].self, from: data)
        #expect(dict["Secret"] == "abc-secret")
    }

    @Test func decodesUserDtoIncludingNewFields() throws {
        let json = """
        {
            "Id": "user-002",
            "Name": "bob",
            "ServerId": "srv-002",
            "PrimaryImageTag": "img-tag-001",
            "HasPassword": true,
            "HasConfiguredPassword": false,
            "LastLoginDate": "2024-01-10T08:00:00.0000000Z",
            "LastActivityDate": "2024-01-10T09:00:00.0000000Z"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let user = try decoder.decode(UserDto.self, from: data)
        #expect(user.id == "user-002")
        #expect(user.name == "bob")
        #expect(user.primaryImageTag == "img-tag-001")
        #expect(user.hasPassword == true)
        #expect(user.hasConfiguredPassword == false)
        #expect(user.lastLoginDate != nil)
        #expect(user.lastActivityDate != nil)
    }
}
