import Foundation
import Observation
import JellyfinAPI
import Persistence

/// Owns the live `JellyfinClient` and `CredentialsStore` and tracks the auth lifecycle.
///
/// Lives at the app root and is shared with `SignInModel` (which writes credentials on
/// successful sign-in) so the same actor instance and Keychain backing store are used end-to-end.
@MainActor
@Observable
public final class SessionStore {

    public enum Phase: Equatable, Sendable {
        case loading
        case signedOut
        case signedIn(UserDto)
        case reconnecting(UserDto?)
    }

    public private(set) var phase: Phase = .loading
    public let client: any JellyfinClientAPI
    public let credentials: CredentialsStore

    public init(client: any JellyfinClientAPI, credentials: CredentialsStore) {
        self.client = client
        self.credentials = credentials
    }

    /// Reads stored credentials and validates them against the server. Distinguishes
    /// token-expired (sign out) from transient network/server errors (reconnecting).
    /// Per critic C8: a network blip on launch must NOT sign the user out.
    public func restore() async {
        let storedURL: URL?
        let storedToken: String?
        do {
            storedURL = try credentials.serverURL()
            storedToken = try credentials.accessToken()
        } catch {
            phase = .signedOut
            return
        }

        guard let serverURL = storedURL, let token = storedToken else {
            phase = .signedOut
            return
        }

        await client.setServerURL(serverURL)
        await client.setAccessToken(token)

        do {
            let user = try await client.currentUser()
            phase = .signedIn(user)
        } catch JellyfinError.unauthenticated {
            try? credentials.clear()
            await client.setAccessToken(nil)
            phase = .signedOut
        } catch JellyfinError.network {
            phase = .reconnecting(nil)
        } catch JellyfinError.http(let status, _) where (500..<600).contains(status) {
            phase = .reconnecting(nil)
        } catch {
            // Decoding errors, unexpected 4xx, etc. — sign out for safety.
            try? credentials.clear()
            await client.setAccessToken(nil)
            phase = .signedOut
        }
    }

    /// Called by the app after `SignInModel` reaches `.signedIn`. The model already
    /// persisted credentials and pushed the token onto the actor; this just propagates
    /// the user into our phase.
    public func didSignIn(user: UserDto) {
        phase = .signedIn(user)
    }

    /// Best-effort logout: tells the server, clears keychain, resets actor state.
    /// Always ends in `.signedOut` regardless of server response.
    public func signOut() async {
        try? await client.logout()
        try? credentials.clear()
        await client.setAccessToken(nil)
        await client.setServerURL(nil)
        phase = .signedOut
    }
}
