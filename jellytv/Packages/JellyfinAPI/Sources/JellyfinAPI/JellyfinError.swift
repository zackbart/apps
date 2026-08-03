import Foundation

public enum JellyfinError: Error, Sendable {
    case invalidServerURL
    case notConfigured
    case network(URLError)
    case http(status: Int, problem: ProblemDetails?)
    case decoding(DecodingError)
    case unauthenticated
    case quickConnectDisabled
    case quickConnectExpired
}
