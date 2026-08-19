import Foundation
@testable import MicroGains

enum Fixtures {
    static let deviceID = "11111111-2222-4333-8444-555555555555"

    static func exercise(
        _ id: String,
        pattern: Pattern,
        unit: SetUnit = .reps,
        easy: Int = 5,
        medium: Int = 10,
        hard: Int = 20,
        officeOk: Bool = true,
        needsFloor: Bool = false,
        intense: Bool = false
    ) -> Exercise {
        Exercise(
            id: id,
            name: id.replacingOccurrences(of: "_", with: " "),
            pattern: pattern,
            unit: unit,
            easy: easy,
            medium: medium,
            hard: hard,
            cue: "Cue for \(id)",
            officeOk: officeOk,
            needsFloor: needsFloor,
            intense: intense
        )
    }

    /// The real catalog shipped in the app bundle. Tests run inside the host
    /// app, so `Bundle.main` is MicroGains.app.
    static let bundledCatalog: [Exercise] = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Exercise].self, from: data)
        else { return [] }
        return decoded
    }()

    /// Two exercises per pattern, all desk friendly, nothing intense.
    static let smallCatalog: [Exercise] = Pattern.allCases.flatMap { pattern in
        [
            exercise("\(pattern.rawValue)_a", pattern: pattern),
            exercise("\(pattern.rawValue)_b", pattern: pattern)
        ]
    }

    static func settings(
        interval: Int = 120,
        difficulty: Difficulty = .medium,
        start: Int = 540,
        end: Int = 1140,
        days: Int = 127,
        office: Bool = false,
        floor: Bool = true,
        enabled: Bool = true,
        pausedUntil: Date? = nil,
        levels: [String: Difficulty] = [:],
        timezone: String = "America/New_York"
    ) -> AppSettings {
        AppSettings(
            intervalMinutes: interval,
            difficulty: difficulty,
            activeStartMinute: start,
            activeEndMinute: end,
            activeDays: days,
            officeMode: office,
            floorOk: floor,
            enabled: enabled,
            pausedUntil: pausedUntil,
            exerciseLevels: levels,
            timezone: timezone
        )
    }

    /// A local wall clock instant in a named zone.
    static func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 0, _ minute: Int = 0,
        zone: String = "America/New_York"
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    static func calendar(_ zone: String = "America/New_York") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }
}

/// Stands in for the network so `APIClient` (and everything above it) can be
/// driven without a Worker. Records every call and answers from `responder`.
final class StubTransport: URLProtocol {
    struct Call {
        let path: String
        let method: String
        let body: Data?

        /// The decoded settings body of a `PUT /api/settings`.
        var settings: AppSettings? {
            guard let body else { return nil }
            return try? APIClient.decoder.decode(AppSettings.self, from: body)
        }
    }

    private static let lock = NSLock()
    private static var recorded: [Call] = []
    static var responder: ((Call) -> (status: Int, body: Data))?
    /// When set, the first call blocks here until the test signals it, which is
    /// how "a request is in flight" becomes a deterministic state.
    static var gate: DispatchSemaphore?

    static var calls: [Call] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    static var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return recorded.count
    }

    static func reset() {
        lock.lock()
        recorded = []
        lock.unlock()
        responder = nil
        gate = nil
    }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubTransport.self]
        return URLSession(configuration: config)
    }

    static func client() -> APIClient {
        APIClient(session: session(), deviceIDProvider: { Fixtures.deviceID })
    }

    // MARK: - Canned bodies

    static func json(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    static let statsJSON: [String: Any] = [
        "today_done": 0, "today_skipped": 0, "streak_days": 0,
        "best_streak_days": 0, "total_done": 0, "total_reps": 0, "total_seconds": 0
    ]

    static func settingsEnvelope(_ settings: AppSettings = Fixtures.settings()) -> Data {
        let encoded = (try? APIClient.encoder.encode(settings)) ?? Data()
        let object = (try? JSONSerialization.jsonObject(with: encoded)) ?? [:]
        return json(["settings": object])
    }

    static func setsEnvelope(
        accepted: Int,
        duplicates: Int = 0,
        rejected: [(id: String, error: String)] = []
    ) -> Data {
        json([
            "accepted": accepted,
            "duplicates": duplicates,
            "rejected": rejected.map { ["id": $0.id, "error": $0.error] },
            "stats": statsJSON
        ])
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let call = Call(
            path: request.url?.path ?? "",
            method: request.httpMethod ?? "GET",
            body: Self.readBody(of: request)
        )
        Self.lock.lock()
        Self.recorded.append(call)
        let index = Self.recorded.count
        Self.lock.unlock()

        if index == 1, let gate = Self.gate { _ = gate.wait(timeout: .now() + 5) }

        let (status, data) = Self.responder?(call) ?? (200, Data("{}".utf8))
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "http://localhost")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession moves `httpBody` into `httpBodyStream` before a protocol sees
    /// the request, so both have to be handled.
    private static func readBody(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
