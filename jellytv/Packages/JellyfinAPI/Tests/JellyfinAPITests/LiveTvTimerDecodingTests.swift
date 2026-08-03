import Testing
import Foundation
@testable import JellyfinAPI

@Suite("LiveTV Timer DTO Decoding")
struct LiveTvTimerDecodingTests {

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    @Test func decodesTimerInfoDto() throws {
        let json = """
        {
            "Id": "timer-001",
            "ChannelId": "ch-001",
            "ChannelName": "MLB Network",
            "ChannelPrimaryImageTag": "abc123",
            "ProgramId": "prog-001",
            "Name": "Yankees vs Red Sox",
            "Overview": "Live MLB action.",
            "StartDate": "2026-04-07T19:00:00.0000000Z",
            "EndDate": "2026-04-07T22:00:00.0000000Z",
            "Status": "New",
            "PrePaddingSeconds": 60,
            "PostPaddingSeconds": 120
        }
        """
        let data = try #require(json.data(using: .utf8))
        let timer = try decoder.decode(TimerInfoDto.self, from: data)
        #expect(timer.id == "timer-001")
        #expect(timer.channelId == "ch-001")
        #expect(timer.channelName == "MLB Network")
        #expect(timer.programId == "prog-001")
        #expect(timer.status == "New")
        #expect(timer.prePaddingSeconds == 60)
        #expect(timer.postPaddingSeconds == 120)
    }

    @Test func decodesTimerInfoDtoQueryResult() throws {
        let json = """
        {
            "Items": [
                { "Id": "t1", "Name": "Show 1" },
                { "Id": "t2", "Name": "Show 2" }
            ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let result = try decoder.decode(TimerInfoDtoQueryResult.self, from: data)
        #expect(result.items.count == 2)
        #expect(result.items[0].id == "t1")
    }

    @Test func decodesSeriesTimerInfoDto() throws {
        let json = """
        {
            "Id": "ser-001",
            "Name": "MLB on FOX",
            "ChannelId": "ch-001",
            "RecordAnyTime": true,
            "RecordAnyChannel": false,
            "RecordNewOnly": true,
            "SkipEpisodesInLibrary": false,
            "KeepUpTo": 5,
            "Days": ["Sunday", "Saturday"]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let timer = try decoder.decode(SeriesTimerInfoDto.self, from: data)
        #expect(timer.id == "ser-001")
        #expect(timer.recordAnyTime == true)
        #expect(timer.recordAnyChannel == false)
        #expect(timer.recordNewOnly == true)
        #expect(timer.keepUpTo == 5)
        #expect(timer.days == ["Sunday", "Saturday"])
    }

    @Test func decodesLiveTvChannelWithCurrentProgram() throws {
        let json = """
        {
            "Id": "ch-001",
            "Name": "MLB Network",
            "Number": "215",
            "ImageTags": { "Primary": "abc" },
            "UserData": { "IsFavorite": true },
            "CurrentProgram": {
                "Id": "prog-001",
                "Name": "Live Game",
                "ChannelId": "ch-001",
                "StartDate": "2026-04-07T19:00:00.0000000Z",
                "EndDate": "2026-04-07T22:00:00.0000000Z",
                "IsLive": true
            }
        }
        """
        let data = try #require(json.data(using: .utf8))
        let channel = try decoder.decode(LiveTvChannel.self, from: data)
        #expect(channel.isFavorite == true)
        #expect(channel.currentProgram?.id == "prog-001")
        #expect(channel.currentProgram?.name == "Live Game")
        #expect(channel.currentProgram?.isLive == true)
    }
}
