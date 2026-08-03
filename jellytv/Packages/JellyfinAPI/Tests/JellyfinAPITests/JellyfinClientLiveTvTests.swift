import Testing
import Foundation
@testable import JellyfinAPI

// Dedicated stub class so this suite's static handler doesn't race with the
// shared `StubURLProtocol` used by `JellyfinClientTests` (Swift Testing runs
// different suites in parallel — `.serialized` only orders within a suite).
final class LiveTvStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = LiveTvStubURLProtocol.handler else {
            fatalError("LiveTvStubURLProtocol.handler not set")
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("JellyfinClient LiveTV", .serialized)
struct JellyfinClientLiveTvTests {

    private let serverURL = URL(string: "http://192.168.1.50:8096")!

    private func makeStubbedClient(
        handler: @escaping (URLRequest) -> (HTTPURLResponse, Data)
    ) -> JellyfinClient {
        LiveTvStubURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LiveTvStubURLProtocol.self]
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

    private func status(_ code: Int, url: URL) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil)!, Data())
    }

    private let channelsJSON = """
    {
        "Items": [
            { "Id": "ch-001", "Name": "MLB Network", "Number": "215", "ChannelType": "TV" },
            { "Id": "ch-002", "Name": "ESPN", "Number": "206", "ChannelType": "TV" }
        ],
        "TotalRecordCount": 2
    }
    """

    private let programsJSON = """
    {
        "Items": [
            {
                "Id": "prog-001",
                "Name": "Yankees vs Red Sox",
                "ChannelId": "ch-001",
                "StartDate": "2026-04-07T19:00:00.0000000Z",
                "EndDate": "2026-04-07T22:00:00.0000000Z",
                "IsLive": true,
                "IsSports": true
            },
            {
                "Id": "prog-002",
                "Name": "SportsCenter",
                "ChannelId": "ch-002",
                "StartDate": "2026-04-07T19:30:00.0000000Z",
                "EndDate": "2026-04-07T20:00:00.0000000Z"
            }
        ]
    }
    """

    // MARK: - Channels

    @Test func liveTvChannelsHitsCorrectPathAndQuery() async throws {
        var capturedURL: URL?
        let client = makeStubbedClient { request in
            capturedURL = request.url
            return self.ok(self.channelsJSON, url: request.url!)
        }
        await client.setServerURL(serverURL)
        _ = try await client.liveTvChannels()

        let url = try #require(capturedURL)
        #expect(url.path == "/LiveTv/Channels")
        let query = url.query ?? ""
        #expect(query.contains("enableImages=true"))
        #expect(query.contains("enableImageTypes=Primary"))
        #expect(query.contains("sortBy=SortName"))
        #expect(query.contains("sortOrder=Ascending"))
    }

    @Test func liveTvChannelsParsesItems() async throws {
        let client = makeStubbedClient { request in
            self.ok(self.channelsJSON, url: request.url!)
        }
        await client.setServerURL(serverURL)
        let channels = try await client.liveTvChannels()
        #expect(channels.count == 2)
        #expect(channels[0].id == "ch-001")
        #expect(channels[0].name == "MLB Network")
        #expect(channels[0].number == "215")
        #expect(channels[1].id == "ch-002")
    }

    @Test func liveTvChannelsUnauthorizedMapsToError() async throws {
        let client = makeStubbedClient { request in
            self.status(401, url: request.url!)
        }
        await client.setServerURL(serverURL)
        do {
            _ = try await client.liveTvChannels()
            Issue.record("Expected unauthenticated to be thrown")
        } catch JellyfinError.unauthenticated {
            // expected
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    // MARK: - Programs

    @Test func liveTvProgramsHitsCorrectPathWithRepeatedChannelIds() async throws {
        var capturedURL: URL?
        let client = makeStubbedClient { request in
            capturedURL = request.url
            return self.ok(self.programsJSON, url: request.url!)
        }
        await client.setServerURL(serverURL)
        let start = Date(timeIntervalSince1970: 1_807_300_800) // 2027-04-07T16:00:00Z, just a stable date
        let end = start.addingTimeInterval(12 * 3600)
        _ = try await client.liveTvPrograms(
            channelIds: ["ch-a", "ch-b", "ch-c"],
            minStartDate: start,
            maxStartDate: end
        )

        let url = try #require(capturedURL)
        #expect(url.path == "/LiveTv/Programs")

        // Use URLComponents to count repeated channelIds
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        let channelItems = items.filter { $0.name == "channelIds" }
        #expect(channelItems.count == 3)
        #expect(channelItems.map(\.value) == ["ch-a", "ch-b", "ch-c"])

        let names = items.map(\.name)
        #expect(names.contains("minStartDate"))
        #expect(names.contains("maxStartDate"))
        #expect(names.contains("sortBy"))
        #expect(names.contains("sortOrder"))
        #expect(names.contains("enableImages"))
        #expect(names.contains("enableTotalRecordCount"))
        #expect(names.contains("limit"))

        let valueFor: (String) -> String? = { name in items.first(where: { $0.name == name })?.value }
        #expect(valueFor("sortBy") == "StartDate")
        #expect(valueFor("sortOrder") == "Ascending")
        #expect(valueFor("enableImages") == "false")
        #expect(valueFor("enableTotalRecordCount") == "false")
        #expect(valueFor("limit") == "2000")
        #expect(valueFor("fields") == "Overview")
    }

    @Test func liveTvProgramsEmptyChannelIdsReturnsEmptyWithoutRequest() async throws {
        var didCallNetwork = false
        let client = makeStubbedClient { request in
            didCallNetwork = true
            return self.ok(self.programsJSON, url: request.url!)
        }
        await client.setServerURL(serverURL)
        let start = Date()
        let end = start.addingTimeInterval(3600)
        let programs = try await client.liveTvPrograms(
            channelIds: [],
            minStartDate: start,
            maxStartDate: end
        )
        #expect(programs.isEmpty)
        #expect(didCallNetwork == false)
    }

    @Test func liveTvProgramsParsesItems() async throws {
        let client = makeStubbedClient { request in
            self.ok(self.programsJSON, url: request.url!)
        }
        await client.setServerURL(serverURL)
        let start = Date()
        let end = start.addingTimeInterval(12 * 3600)
        let programs = try await client.liveTvPrograms(
            channelIds: ["ch-001", "ch-002"],
            minStartDate: start,
            maxStartDate: end
        )
        #expect(programs.count == 2)
        #expect(programs[0].name == "Yankees vs Red Sox")
        #expect(programs[0].channelId == "ch-001")
        #expect(programs[0].isLive == true)
        #expect(programs[1].channelId == "ch-002")
    }

    @Test func liveTvProgramsUnauthorizedMapsToError() async throws {
        let client = makeStubbedClient { request in
            self.status(401, url: request.url!)
        }
        await client.setServerURL(serverURL)
        do {
            _ = try await client.liveTvPrograms(
                channelIds: ["ch-001"],
                minStartDate: Date(),
                maxStartDate: Date().addingTimeInterval(3600)
            )
            Issue.record("Expected unauthenticated to be thrown")
        } catch JellyfinError.unauthenticated {
            // expected
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    @Test func liveTvProgramsDateFormatIsISO8601() async throws {
        var capturedURL: URL?
        let client = makeStubbedClient { request in
            capturedURL = request.url
            return self.ok(self.programsJSON, url: request.url!)
        }
        await client.setServerURL(serverURL)
        // Stable known date: 2026-04-07 19:00:00 UTC
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 7
        components.hour = 19
        components.timeZone = TimeZone(identifier: "UTC")
        let start = try #require(Calendar(identifier: .gregorian).date(from: components))
        let end = start.addingTimeInterval(12 * 3600)
        _ = try await client.liveTvPrograms(
            channelIds: ["ch-001"],
            minStartDate: start,
            maxStartDate: end
        )
        let url = try #require(capturedURL)
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = comps?.queryItems ?? []
        let minStart = items.first(where: { $0.name == "minStartDate" })?.value
        let maxStart = items.first(where: { $0.name == "maxStartDate" })?.value
        #expect(minStart == "2026-04-07T19:00:00Z")
        #expect(maxStart == "2026-04-08T07:00:00Z")
    }
}
