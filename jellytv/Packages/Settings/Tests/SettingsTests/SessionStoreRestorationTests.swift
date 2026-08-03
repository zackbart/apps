import Testing
import Foundation
@testable import Settings
@testable import JellyfinAPI
@testable import Persistence

@MainActor
@Suite("SessionStore restoration")
struct SessionStoreRestorationTests {

    private func makeStore(
        client: MockJellyfinClient,
        prefilled: (URL, String)? = nil
    ) throws -> (SessionStore, CredentialsStore) {
        let credentials = CredentialsStore(service: "com.cursorkittens.jellytv.test.\(UUID().uuidString)")
        if let (url, token) = prefilled {
            try credentials.setServerURL(url)
            try credentials.setAccessToken(token)
        }
        return (SessionStore(client: client, credentials: credentials), credentials)
    }

    @Test func startsInLoading() throws {
        let (store, _) = try makeStore(client: MockJellyfinClient())
        #expect(store.phase == .loading)
    }

    @Test func noCredentialsTransitionsToSignedOut() async throws {
        let client = MockJellyfinClient()
        let (store, _) = try makeStore(client: client)
        await store.restore()
        #expect(store.phase == .signedOut)
        #expect(client.currentUserCallCount == 0)
    }

    @Test func validCredentialsTransitionToSignedIn() async throws {
        let client = MockJellyfinClient()
        let user = UserDto(
            id: "u1", name: "Alice", serverId: "s1",
            primaryImageTag: nil, hasPassword: true, hasConfiguredPassword: true,
            lastLoginDate: nil, lastActivityDate: nil
        )
        client.currentUserResult = .success(user)
        let (store, creds) = try makeStore(
            client: client,
            prefilled: (URL(string: "http://192.168.1.50:8096")!, "tok-123")
        )
        defer { try? creds.clear() }

        await store.restore()

        #expect(store.phase == .signedIn(user))
        // Client was configured from credentials.
        #expect(client.setServerURLCalls.last == URL(string: "http://192.168.1.50:8096")!)
        #expect(client.setAccessTokenCalls.last == "tok-123")
    }

    @Test func unauthenticatedClearsCredentialsAndSignsOut() async throws {
        let client = MockJellyfinClient()
        client.currentUserResult = .failure(JellyfinError.unauthenticated)
        let (store, creds) = try makeStore(
            client: client,
            prefilled: (URL(string: "http://server")!, "expired-token")
        )

        await store.restore()

        #expect(store.phase == .signedOut)
        #expect(try creds.accessToken() == nil)
        #expect(try creds.serverURL() == nil)
    }

    @Test func networkErrorKeepsCredentialsAndShowsReconnecting() async throws {
        let client = MockJellyfinClient()
        client.currentUserResult = .failure(JellyfinError.network(URLError(.notConnectedToInternet)))
        let (store, creds) = try makeStore(
            client: client,
            prefilled: (URL(string: "http://server")!, "tok")
        )
        defer { try? creds.clear() }

        await store.restore()

        if case .reconnecting = store.phase {
            // pass
        } else {
            Issue.record("expected .reconnecting, got \(store.phase)")
        }
        // Critically: credentials are NOT cleared on network error.
        #expect(try creds.accessToken() == "tok")
        #expect(try creds.serverURL()?.absoluteString == "http://server")
    }

    @Test func httpServerErrorKeepsCredentialsAndShowsReconnecting() async throws {
        let client = MockJellyfinClient()
        client.currentUserResult = .failure(JellyfinError.http(status: 503, problem: nil))
        let (store, creds) = try makeStore(
            client: client,
            prefilled: (URL(string: "http://server")!, "tok")
        )
        defer { try? creds.clear() }

        await store.restore()

        if case .reconnecting = store.phase {
            // pass
        } else {
            Issue.record("expected .reconnecting, got \(store.phase)")
        }
        #expect(try creds.accessToken() == "tok")
    }

    @Test func didSignInTransitionsToSignedIn() throws {
        let user = UserDto(
            id: "u2", name: "Bob", serverId: nil,
            primaryImageTag: nil, hasPassword: nil, hasConfiguredPassword: nil,
            lastLoginDate: nil, lastActivityDate: nil
        )
        let (store, _) = try makeStore(client: MockJellyfinClient())
        store.didSignIn(user: user)
        #expect(store.phase == .signedIn(user))
    }

    @Test func signOutClearsCredentialsAndTransitions() async throws {
        let client = MockJellyfinClient()
        let (store, creds) = try makeStore(
            client: client,
            prefilled: (URL(string: "http://server")!, "tok")
        )

        await store.signOut()

        #expect(store.phase == .signedOut)
        #expect(client.logoutCallCount == 1)
        #expect(try creds.accessToken() == nil)
        #expect(try creds.serverURL() == nil)
    }
}
