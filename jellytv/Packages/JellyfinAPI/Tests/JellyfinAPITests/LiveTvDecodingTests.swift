import Testing
import Foundation
@testable import JellyfinAPI

@Suite("LiveTV DTO Decoding")
struct LiveTvDecodingTests {

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    @Test func decodesLiveTvChannel() throws {
        let json = """
        {
            "Id": "ch-001",
            "Name": "MLB Network",
            "Number": "215",
            "ChannelType": "TV",
            "ServerId": "srv-001",
            "ImageTags": {
                "Primary": "abc123"
            }
        }
        """
        let data = try #require(json.data(using: .utf8))
        let channel = try decoder.decode(LiveTvChannel.self, from: data)
        #expect(channel.id == "ch-001")
        #expect(channel.name == "MLB Network")
        #expect(channel.number == "215")
        #expect(channel.channelType == "TV")
        #expect(channel.serverId == "srv-001")
        #expect(channel.imageTags?["Primary"] == "abc123")
    }

    @Test func decodesLiveTvChannelMinimal() throws {
        let json = """
        {
            "Id": "ch-002",
            "Name": "ESPN"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let channel = try decoder.decode(LiveTvChannel.self, from: data)
        #expect(channel.id == "ch-002")
        #expect(channel.name == "ESPN")
        #expect(channel.number == nil)
        #expect(channel.channelType == nil)
    }

    @Test func decodesLiveTvChannelQueryResult() throws {
        let json = """
        {
            "Items": [
                { "Id": "ch-001", "Name": "MLB Network" },
                { "Id": "ch-002", "Name": "ESPN" }
            ],
            "TotalRecordCount": 2
        }
        """
        let data = try #require(json.data(using: .utf8))
        let result = try decoder.decode(LiveTvChannelQueryResult.self, from: data)
        #expect(result.items.count == 2)
        #expect(result.totalRecordCount == 2)
        #expect(result.items[0].name == "MLB Network")
    }

    /// Verifies the existing `.iso8601` strategy handles .NET's 7-digit fractional second
    /// ISO8601 format used by Jellyfin's `/LiveTv/Programs` response.
    @Test func decodesLiveTvProgramWith7DigitFractionalSeconds() throws {
        let json = """
        {
            "Id": "prog-001",
            "Name": "Yankees vs Red Sox",
            "ChannelId": "ch-001",
            "Overview": "MLB baseball.",
            "StartDate": "2026-04-07T19:00:00.0000000Z",
            "EndDate": "2026-04-07T22:00:00.0000000Z",
            "IsLive": true,
            "IsSports": true,
            "IsRepeat": false
        }
        """
        let data = try #require(json.data(using: .utf8))
        let program = try decoder.decode(LiveTvProgram.self, from: data)
        #expect(program.id == "prog-001")
        #expect(program.name == "Yankees vs Red Sox")
        #expect(program.channelId == "ch-001")
        #expect(program.isLive == true)
        #expect(program.isSports == true)
        #expect(program.isRepeat == false)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expectedStart = try #require(formatter.date(from: "2026-04-07T19:00:00.0000000Z"))
        let expectedEnd = try #require(formatter.date(from: "2026-04-07T22:00:00.0000000Z"))
        #expect(program.startDate == expectedStart)
        #expect(program.endDate == expectedEnd)
    }

    @Test func decodesLiveTvProgramWithoutFractionalSeconds() throws {
        let json = """
        {
            "Id": "prog-002",
            "Name": "SportsCenter",
            "ChannelId": "ch-002",
            "StartDate": "2026-04-07T19:30:00Z",
            "EndDate": "2026-04-07T20:00:00Z"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let program = try decoder.decode(LiveTvProgram.self, from: data)
        #expect(program.id == "prog-002")
        #expect(program.startDate != nil)
        #expect(program.endDate != nil)
    }

    @Test func decodesLiveTvProgramMinimal() throws {
        let json = """
        {
            "Id": "prog-003",
            "Name": "Unknown Show"
        }
        """
        let data = try #require(json.data(using: .utf8))
        let program = try decoder.decode(LiveTvProgram.self, from: data)
        #expect(program.id == "prog-003")
        #expect(program.name == "Unknown Show")
        #expect(program.channelId == nil)
        #expect(program.startDate == nil)
        #expect(program.endDate == nil)
    }

    @Test func decodesLiveTvProgramQueryResult() throws {
        let json = """
        {
            "Items": [
                {
                    "Id": "prog-001",
                    "Name": "Yankees vs Red Sox",
                    "ChannelId": "ch-001",
                    "StartDate": "2026-04-07T19:00:00.0000000Z",
                    "EndDate": "2026-04-07T22:00:00.0000000Z"
                },
                {
                    "Id": "prog-002",
                    "Name": "Postgame",
                    "ChannelId": "ch-001",
                    "StartDate": "2026-04-07T22:00:00.0000000Z",
                    "EndDate": "2026-04-07T22:30:00.0000000Z"
                }
            ],
            "TotalRecordCount": 2
        }
        """
        let data = try #require(json.data(using: .utf8))
        let result = try decoder.decode(LiveTvProgramQueryResult.self, from: data)
        #expect(result.items.count == 2)
        #expect(result.items[0].name == "Yankees vs Red Sox")
        #expect(result.items[1].channelId == "ch-001")
    }
}
