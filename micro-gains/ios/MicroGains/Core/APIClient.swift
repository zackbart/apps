import Foundation

/// Thin wrapper over URLSession. Every call is best-effort: nothing here blocks
/// the UI and nothing here surfaces an error to the user. The app works fully
/// offline, so a failed request just gets retried on the next sync pass.
final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    /// Set in Info.plist from the MICRO_GAINS_API_URL build setting.
    /// Debug builds point at the local wrangler dev server on 127.0.0.1:8788;
    /// release builds point at the deployed Worker (see project.yml).
    static let baseURL: URL = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "MICRO_GAINS_API_URL") as? String)?
            .trimmingCharacters(in: .whitespaces)
        if let raw, !raw.contains("<"), let url = URL(string: raw), url.scheme != nil {
            return url
        }
        // The release URL still has its <subdomain> placeholder in it. Sync is
        // best-effort, so the app keeps working; it just talks to nobody.
        NSLog("[MicroGains] MICRO_GAINS_API_URL is not set (%@); falling back to localhost", raw ?? "nil")
        return URL(string: "http://127.0.0.1:8788")!
    }()

    enum Failure: Error {
        case http(Int)
        case malformed
        case offline
    }

    private let session: URLSession
    private let deviceIDProvider: () -> String

    init(session: URLSession? = nil, deviceIDProvider: @escaping () -> String = { DeviceID.current }) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 12
            config.waitsForConnectivity = false
            self.session = URLSession(configuration: config)
        }
        self.deviceIDProvider = deviceIDProvider
    }

    // MARK: - Wire models

    struct MeResponse: Codable, Sendable {
        let deviceID: String
        let settings: AppSettings
        let stats: Stats
        let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case deviceID = "device_id"
            case settings, stats
            case createdAt = "created_at"
        }
    }

    struct SettingsResponse: Codable, Sendable {
        let settings: AppSettings
    }

    struct CatalogResponse: Codable, Sendable {
        let exercises: [Exercise]
        let version: String
    }

    struct SetsRequest: Codable, Sendable {
        let sets: [SetLog]
    }

    struct RejectedSet: Codable, Sendable {
        let id: String
        let error: String
    }

    struct SetsResponse: Codable, Sendable {
        let accepted: Int
        let duplicates: Int
        let rejected: [RejectedSet]
        let stats: Stats
    }

    struct HistoryResponse: Codable, Sendable {
        let days: [HistoryDay]
        let stats: Stats
    }

    // MARK: - Routes

    func me() async throws -> MeResponse {
        try await send(path: "/api/me", method: "GET", body: Optional<Never>.none)
    }

    func putSettings(_ settings: AppSettings) async throws -> AppSettings {
        let response: SettingsResponse = try await send(path: "/api/settings", method: "PUT", body: settings)
        return response.settings
    }

    func postSets(_ sets: [SetLog]) async throws -> SetsResponse {
        try await send(path: "/api/sets", method: "POST", body: SetsRequest(sets: sets))
    }

    func history(days: Int = 30) async throws -> HistoryResponse {
        try await send(path: "/api/history?days=\(days)", method: "GET", body: Optional<Never>.none)
    }

    /// Returns nil on 304, meaning the bundled or cached copy is current.
    func catalog(etag: String?) async throws -> CatalogResponse? {
        var request = makeRequest(path: "/api/catalog", method: "GET")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.malformed }
        if http.statusCode == 304 { return nil }
        guard (200..<300).contains(http.statusCode) else { throw Failure.http(http.statusCode) }
        return try Self.decoder.decode(CatalogResponse.self, from: data)
    }

    func deleteMe() async throws {
        let request = makeRequest(path: "/api/me", method: "DELETE")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.malformed }
        guard (200..<300).contains(http.statusCode) else { throw Failure.http(http.statusCode) }
    }

    // MARK: - Plumbing

    private func makeRequest(path: String, method: String) -> URLRequest {
        var request = URLRequest(url: URL(string: path, relativeTo: Self.baseURL) ?? Self.baseURL)
        request.httpMethod = method
        request.setValue(deviceIDProvider(), forHTTPHeaderField: "X-Device-Id")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        var request = makeRequest(path: path, method: method)
        if let body {
            request.httpBody = try Self.encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.malformed }
        guard (200..<300).contains(http.statusCode) else { throw Failure.http(http.statusCode) }
        return try Self.decoder.decode(Response.self, from: data)
    }

    /// The wire format is snake_case with ISO8601 timestamps. Every model spells
    /// its own keys, so no key strategy is needed.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601.offsetString(date, timeZone: .current))
        }
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = ISO8601.parse(raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "bad date \(raw)")
                )
            }
            return date
        }
        return decoder
    }()
}
