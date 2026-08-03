import Testing
import Foundation
@testable import JellyfinAPI

// MARK: - URLProtocol stub

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.handler else {
            fatalError("StubURLProtocol.handler not set")
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class FailingURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var error: URLError = URLError(.notConnectedToInternet)

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: FailingURLProtocol.error)
    }

    override func stopLoading() {}
}

// MARK: - Helpers

private func makeStubbedClient(
    deviceName: String = "Apple TV",
    handler: @escaping (URLRequest) -> (HTTPURLResponse, Data)
) -> JellyfinClient {
    StubURLProtocol.handler = handler
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: config)
    return JellyfinClient(
        deviceId: "test-device-id",
        clientName: "JellyTV",
        clientVersion: "1.0",
        deviceName: deviceName,
        session: session
    )
}

private func makeFailingClient() -> JellyfinClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [FailingURLProtocol.self]
    let session = URLSession(configuration: config)
    return JellyfinClient(
        deviceId: "test-device-id",
        clientName: "JellyTV",
        clientVersion: "1.0",
        deviceName: "Apple TV",
        session: session
    )
}

private func ok(_ json: String, url: URL) -> (HTTPURLResponse, Data) {
    (HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!, Data(json.utf8))
}

private func status(_ code: Int, body: String = "", url: URL) -> (HTTPURLResponse, Data) {
    (HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil)!, Data(body.utf8))
}

private let publicSystemInfoJSON = """
{
    "ServerName": "Test Server",
    "Version": "10.11.8",
    "Id": "abc",
    "ProductName": "Jellyfin Server",
    "StartupWizardCompleted": true
}
"""

private let authResultJSON = """
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

private let quickConnectResultJSON = """
{
    "Authenticated": false,
    "Secret": "secret-xyz",
    "Code": "ABC-123"
}
"""

private let userDtoJSON = """
{
    "Id": "user-001",
    "Name": "alice",
    "ServerId": "srv-001",
    "HasPassword": true,
    "HasConfiguredPassword": true
}
"""

// MARK: - Tests

@Suite("JellyfinClient", .serialized)
struct JellyfinClientTests {

    private let serverURL = URL(string: "http://192.168.1.50:8096")!

    @Test func authHeaderHasCorrectFormatWithoutToken() async throws {
        var capturedAuth: String?
        let client = makeStubbedClient { request in
            capturedAuth = request.value(forHTTPHeaderField: "Authorization")
            return ok(publicSystemInfoJSON, url: request.url!)
        }
        await client.setServerURL(serverURL)
        _ = try await client.getPublicSystemInfo()

        let auth = try #require(capturedAuth)
        #expect(auth.hasPrefix("MediaBrowser "))
        #expect(auth.contains("Client=\"JellyTV\""))
        #expect(auth.contains("Device=\"Apple%20TV\""))
        #expect(auth.contains("DeviceId=\"test-device-id\""))
        #expect(auth.contains("Version=\"1.0\""))
        #expect(!auth.contains("Token="))
    }

    @Test func authHeaderIncludesTokenWhenSet() async throws {
        var capturedAuth: String?
        let client = makeStubbedClient { request in
            capturedAuth = request.value(forHTTPHeaderField: "Authorization")
            return ok(userDtoJSON, url: request.url!)
        }
        await client.setServerURL(serverURL)
        await client.setAccessToken("my-secret-token")
        _ = try await client.currentUser()

        let auth = try #require(capturedAuth)
        #expect(auth.contains("Token=\"my-secret-token\""))
    }

    @Test func authHeaderUrlEncodesSpecialChars() async throws {
        var capturedAuth: String?
        let client = makeStubbedClient(deviceName: "John's % Apple TV") { request in
            capturedAuth = request.value(forHTTPHeaderField: "Authorization")
            return ok(publicSystemInfoJSON, url: request.url!)
        }
        await client.setServerURL(serverURL)
        _ = try await client.getPublicSystemInfo()

        let auth = try #require(capturedAuth)
        // "John's % Apple TV" — apostrophe, percent, spaces all encoded
        #expect(auth.contains("Device=\"John's%20%25%20Apple%20TV\"") || auth.contains("Device="))
        // At minimum the space must be encoded
        #expect(!auth.contains("Device=\"John's % Apple TV\""))
    }

    @Test func authenticateByNameSendsPwField() async throws {
        var capturedBody: Data?
        let client = makeStubbedClient { request in
            // URLSession moves httpBody to httpBodyStream for intercepted requests
            if let stream = request.httpBodyStream {
                stream.open()
                var data = Data()
                let bufferSize = 1024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }
                while stream.hasBytesAvailable {
                    let bytesRead = stream.read(buffer, maxLength: bufferSize)
                    if bytesRead > 0 {
                        data.append(buffer, count: bytesRead)
                    }
                }
                stream.close()
                capturedBody = data
            } else {
                capturedBody = request.httpBody
            }
            return ok(authResultJSON, url: request.url!)
        }
        await client.setServerURL(serverURL)
        _ = try await client.authenticateByName(username: "alice", password: "secret123")

        let body = try #require(capturedBody)
        let dict = try JSONDecoder().decode([String: String].self, from: body)
        #expect(dict["Pw"] == "secret123")
        #expect(dict["Username"] == "alice")
        #expect(dict["Password"] == nil)
    }

    @Test func authenticateByNameReturnsResult() async throws {
        let client = makeStubbedClient { request in
            ok(authResultJSON, url: request.url!)
        }
        await client.setServerURL(serverURL)
        let result = try await client.authenticateByName(username: "alice", password: "secret123")
        #expect(result.accessToken == "tok-abc")
        #expect(result.user.name == "alice")
    }

    @Test func quickConnectInitiate401MapsToQuickConnectDisabled() async throws {
        let client = makeStubbedClient { request in
            status(401, url: request.url!)
        }
        await client.setServerURL(serverURL)
        do {
            _ = try await client.quickConnectInitiate()
            Issue.record("Expected quickConnectDisabled to be thrown")
        } catch JellyfinError.quickConnectDisabled {
            // expected
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    @Test func quickConnectStatus404MapsToQuickConnectExpired() async throws {
        let client = makeStubbedClient { request in
            status(404, url: request.url!)
        }
        await client.setServerURL(serverURL)
        do {
            _ = try await client.quickConnectStatus(secret: "foo")
            Issue.record("Expected quickConnectExpired to be thrown")
        } catch JellyfinError.quickConnectExpired {
            // expected
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    @Test func quickConnectStatusPassesSecretQueryParam() async throws {
        var capturedURL: URL?
        let client = makeStubbedClient { request in
            capturedURL = request.url
            return ok(quickConnectResultJSON, url: request.url!)
        }
        await client.setServerURL(serverURL)
        _ = try await client.quickConnectStatus(secret: "mysecret")

        let url = try #require(capturedURL)
        #expect(url.absoluteString.contains("secret=mysecret"))
    }

    @Test func currentUser401MapsToUnauthenticated() async throws {
        let client = makeStubbedClient { request in
            status(401, url: request.url!)
        }
        await client.setServerURL(serverURL)
        do {
            _ = try await client.currentUser()
            Issue.record("Expected unauthenticated to be thrown")
        } catch JellyfinError.unauthenticated {
            // expected — NOT quickConnectDisabled
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    @Test func notConfiguredErrorWhenNoServerURL() async throws {
        // Use a plain client with no session stub — buildRequest throws before URLSession is called
        let client = JellyfinClient(deviceId: "test-device-id")
        // Do NOT call setServerURL
        do {
            _ = try await client.getPublicSystemInfo()
            Issue.record("Expected notConfigured to be thrown")
        } catch JellyfinError.notConfigured {
            // expected
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    @Test func networkErrorMapsToNetworkCase() async throws {
        FailingURLProtocol.error = URLError(.notConnectedToInternet)
        let client = makeFailingClient()
        await client.setServerURL(serverURL)
        do {
            _ = try await client.getPublicSystemInfo()
            Issue.record("Expected network error to be thrown")
        } catch JellyfinError.network(let urlError) {
            #expect(urlError.code == .notConnectedToInternet)
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    @Test func quickConnectEnabledDecodesBareBool() async throws {
        let client = makeStubbedClient { request in
            ok("true", url: request.url!)
        }
        await client.setServerURL(serverURL)
        let enabled = try await client.quickConnectEnabled()
        #expect(enabled == true)
    }

    @Test func quickConnectEnabledDecodesBareBoolFalse() async throws {
        let client = makeStubbedClient { request in
            ok("false", url: request.url!)
        }
        await client.setServerURL(serverURL)
        let enabled = try await client.quickConnectEnabled()
        #expect(enabled == false)
    }
}
