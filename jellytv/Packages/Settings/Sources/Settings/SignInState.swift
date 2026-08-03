import JellyfinAPI

public enum SignInState: Equatable, Sendable {
    case enteringServerURL
    case validatingServer
    case chooseMode(serverName: String)
    case quickConnectStarting
    case quickConnect(code: String, secret: String)
    case enteringPassword
    case authenticating
    case signedIn(UserDto)
    case failed(SignInError)
}

public enum SignInError: Error, Equatable, Sendable {
    case invalidServerURL
    case serverUnreachable
    case quickConnectDisabled
    case quickConnectExpired
    case invalidCredentials
    case persistFailed
    case unknown(String)

    public var message: String {
        switch self {
        case .invalidServerURL:
            return "That doesn't look like a valid server URL. Try http://192.168.1.50:8096"
        case .serverUnreachable:
            return "Couldn't reach the server. Check the URL and that the server is running."
        case .quickConnectDisabled:
            return "Quick Connect is not enabled on this server. Use username and password instead."
        case .quickConnectExpired:
            return "The Quick Connect code expired. Please try again."
        case .invalidCredentials:
            return "Wrong username or password."
        case .persistFailed:
            return "Couldn't save your sign-in. Try again."
        case .unknown(let m):
            return "Sign-in failed: \(m)"
        }
    }
}
