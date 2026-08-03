import Testing
import Foundation
@testable import Settings
@testable import JellyfinAPI
@testable import Persistence

@MainActor
@Suite("SignInModel")
struct SignInModelTests {

    private func makeModel(client: MockJellyfinClient = MockJellyfinClient()) -> (SignInModel, CredentialsStore) {
        let store = CredentialsStore(service: "com.cursorkittens.jellytv.test.\(UUID().uuidString)")
        let model = SignInModel(client: client, credentials: store)
        return (model, store)
    }

    @Test func startsInEnteringServerURL() {
        let (model, _) = makeModel()
        #expect(model.state == .enteringServerURL)
    }

    @Test func normalizeServerURLPrependsHttp() throws {
        let url = try SignInModel.normalizeServerURL("192.168.1.50:8096")
        #expect(url.absoluteString == "http://192.168.1.50:8096")
    }

    @Test func normalizeServerURLPreservesHttps() throws {
        let url = try SignInModel.normalizeServerURL("https://my.server")
        #expect(url.absoluteString == "https://my.server")
    }

    @Test func normalizeServerURLRejectsEmpty() {
        #expect(throws: SignInError.invalidServerURL) {
            _ = try SignInModel.normalizeServerURL("   ")
        }
    }

    @Test func connectToServerSuccess() async {
        let (model, _) = makeModel()
        model.serverURLInput = "192.168.1.50:8096"
        await model.connectToServer()
        if case .chooseMode(let name) = model.state {
            #expect(name == "MockServer")
        } else {
            Issue.record("expected .chooseMode, got \(model.state)")
        }
    }

    @Test func connectToServerInvalidURL() async {
        let (model, _) = makeModel()
        model.serverURLInput = ""
        await model.connectToServer()
        #expect(model.state == .failed(.invalidServerURL))
    }

    @Test func connectToServerNetworkError() async {
        let client = MockJellyfinClient()
        client.publicSystemInfoResult = .failure(JellyfinError.network(URLError(.notConnectedToInternet)))
        let (model, _) = makeModel(client: client)
        model.serverURLInput = "192.168.1.50:8096"
        await model.connectToServer()
        #expect(model.state == .failed(.serverUnreachable))
    }

    @Test func quickConnectDisabledMaps() async {
        let client = MockJellyfinClient()
        client.quickConnectInitiateResult = .failure(JellyfinError.quickConnectDisabled)
        let (model, _) = makeModel(client: client)
        await model.chooseQuickConnect()
        #expect(model.state == .failed(.quickConnectDisabled))
    }

    @Test func quickConnectExpiredMapsViaPollLoop() async {
        let client = MockJellyfinClient()
        client.quickConnectInitiateResult = .success(
            QuickConnectResult(authenticated: false, secret: "s1", code: "C1", deviceId: nil, deviceName: nil, appName: nil, appVersion: nil, dateAdded: nil)
        )
        client.quickConnectStatusResults = [.failure(JellyfinError.quickConnectExpired)]
        let (model, _) = makeModel(client: client)
        model.pollInterval = .milliseconds(10)
        model.serverURLInput = "192.168.1.50:8096"
        await model.pollQuickConnectLoop(secret: "s1")
        #expect(model.state == .failed(.quickConnectExpired))
    }

    @Test func passwordSignInSuccess() async throws {
        let client = MockJellyfinClient()
        let user = UserDto(id: "u1", name: "Alice", serverId: "s1", primaryImageTag: nil, hasPassword: true, hasConfiguredPassword: true, lastLoginDate: nil, lastActivityDate: nil)
        client.authenticateByNameResult = .success(
            AuthenticationResult(user: user, sessionInfo: nil, accessToken: "tok-123", serverId: "s1")
        )
        let (model, store) = makeModel(client: client)
        defer { try? store.clear() }
        model.serverURLInput = "192.168.1.50:8096"
        model.username = "alice"
        model.password = "secret"
        await model.signInWithPassword()
        #expect(model.state == .signedIn(user))
        #expect(try store.accessToken() == "tok-123")
        #expect(try store.serverURL()?.absoluteString == "http://192.168.1.50:8096")
    }

    @Test func passwordSignInWrongCredentials() async {
        let client = MockJellyfinClient()
        client.authenticateByNameResult = .failure(JellyfinError.unauthenticated)
        let (model, _) = makeModel(client: client)
        model.serverURLInput = "192.168.1.50:8096"
        model.username = "alice"
        model.password = "wrong"
        await model.signInWithPassword()
        #expect(model.state == .failed(.invalidCredentials))
    }
}
