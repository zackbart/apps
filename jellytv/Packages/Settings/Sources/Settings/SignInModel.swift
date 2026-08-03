import Foundation
import Observation
import JellyfinAPI
import Persistence

@MainActor
@Observable
public final class SignInModel {
    public private(set) var state: SignInState = .enteringServerURL
    public var serverURLInput: String = ""
    public var username: String = ""
    public var password: String = ""

    private let client: any JellyfinClientAPI
    private let credentials: CredentialsStore
    @ObservationIgnored nonisolated(unsafe) private var pollingTask: Task<Void, Never>?

    // Internal so tests can override for faster polling.
    var pollInterval: Duration = .seconds(2)

    public init(client: any JellyfinClientAPI, credentials: CredentialsStore) {
        self.client = client
        self.credentials = credentials
    }

    /// Validates and sets the server URL on the client. Transitions to `.chooseMode` on success.
    public func connectToServer() async {
        state = .validatingServer
        do {
            let url = try Self.normalizeServerURL(serverURLInput)
            await client.setServerURL(url)
            let info = try await client.getPublicSystemInfo()
            state = .chooseMode(serverName: info.serverName ?? url.host ?? "Jellyfin")
        } catch JellyfinError.invalidServerURL {
            state = .failed(.invalidServerURL)
        } catch let error as SignInError {
            state = .failed(error)
        } catch JellyfinError.network {
            state = .failed(.serverUnreachable)
        } catch JellyfinError.http(let status, _) where (500..<600).contains(status) {
            state = .failed(.serverUnreachable)
        } catch {
            state = .failed(.unknown(String(describing: error)))
        }
    }

    /// Normalizes a user-typed server URL: trims whitespace,
    /// prepends http:// if no scheme, requires the result to have a non-nil host.
    public static func normalizeServerURL(_ raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SignInError.invalidServerURL }
        let withScheme: String
        if trimmed.contains("://") {
            withScheme = trimmed
        } else {
            withScheme = "http://" + trimmed
        }
        guard let url = URL(string: withScheme), url.host != nil else {
            throw SignInError.invalidServerURL
        }
        return url
    }

    public func chooseQuickConnect() async {
        state = .quickConnectStarting
        do {
            let result = try await client.quickConnectInitiate()
            state = .quickConnect(code: result.code, secret: result.secret)
            startPollingQuickConnect(secret: result.secret)
        } catch JellyfinError.quickConnectDisabled {
            state = .failed(.quickConnectDisabled)
        } catch JellyfinError.network {
            state = .failed(.serverUnreachable)
        } catch {
            state = .failed(.unknown(String(describing: error)))
        }
    }

    public func choosePassword() {
        state = .enteringPassword
    }

    /// Polls /QuickConnect/Connect until Authenticated, then exchanges for a token.
    /// Internal so tests can call it directly without the spawned Task.
    func pollQuickConnectLoop(secret: String) async {
        do {
            while !Task.isCancelled {
                try await Task.sleep(for: pollInterval)
                let status = try await client.quickConnectStatus(secret: secret)
                if status.authenticated {
                    state = .authenticating
                    let result = try await client.authenticateWithQuickConnect(secret: secret)
                    await finishSignIn(result: result)
                    return
                }
            }
        } catch is CancellationError {
            return
        } catch JellyfinError.quickConnectExpired {
            state = .failed(.quickConnectExpired)
        } catch JellyfinError.network {
            state = .failed(.serverUnreachable)
        } catch {
            state = .failed(.unknown(String(describing: error)))
        }
    }

    private func startPollingQuickConnect(secret: String) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            await self?.pollQuickConnectLoop(secret: secret)
        }
    }

    public func cancelQuickConnect() {
        pollingTask?.cancel()
        pollingTask = nil
        state = .enteringServerURL
    }

    public func signInWithPassword() async {
        state = .authenticating
        do {
            let result = try await client.authenticateByName(username: username, password: password)
            await finishSignIn(result: result)
        } catch JellyfinError.unauthenticated {
            state = .failed(.invalidCredentials)
        } catch JellyfinError.http(let status, _) where status == 400 || status == 401 {
            state = .failed(.invalidCredentials)
        } catch JellyfinError.network {
            state = .failed(.serverUnreachable)
        } catch {
            state = .failed(.unknown(String(describing: error)))
        }
    }

    private func finishSignIn(result: AuthenticationResult) async {
        do {
            let url = try Self.normalizeServerURL(serverURLInput)
            try credentials.setServerURL(url)
            try credentials.setAccessToken(result.accessToken)
            await client.setAccessToken(result.accessToken)
            state = .signedIn(result.user)
        } catch {
            state = .failed(.persistFailed)
        }
    }

    public func reset() {
        pollingTask?.cancel()
        pollingTask = nil
        state = .enteringServerURL
    }

    deinit {
        pollingTask?.cancel()
    }
}
