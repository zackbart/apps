import Testing
import Foundation
@testable import JellyfinAPI

// Dedicated stub class so this suite's static handler doesn't race with the
// shared URL protocols used by other suites (Swift Testing runs different
// suites in parallel — `.serialized` only orders within a suite).
final class LiveTvStreamStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = LiveTvStreamStubURLProtocol.handler else {
            fatalError("LiveTvStreamStubURLProtocol.handler not set")
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("JellyfinClient LiveTV Stream", .serialized)
struct JellyfinClientLiveTvStreamTests {

    private let serverURL = URL(string: "http://192.168.1.50:8096")!

    private func makeStubbedClient(
        handler: @escaping (URLRequest) -> (HTTPURLResponse, Data)
    ) -> JellyfinClient {
        LiveTvStreamStubURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LiveTvStreamStubURLProtocol.self]
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

    /// Reads body from `httpBodyStream` (URLSession moves `httpBody` →
    /// `httpBodyStream` for intercepted requests, mirroring the pattern in
    /// JellyfinClientTests.swift:186-200).
    private func readBody(_ request: URLRequest) -> Data? {
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let bytesRead = stream.read(buffer, maxLength: bufferSize)
                if bytesRead > 0 {
                    data.append(buffer, count: bytesRead)
                }
            }
            stream.close()
            return data
        }
        return request.httpBody
    }

    private let userMeJSON = """
    {
        "Id": "user-001",
        "Name": "alice",
        "ServerId": "srv-001",
        "HasPassword": true,
        "HasConfiguredPassword": true
    }
    """

    private let transcodingResponseJSON = """
    {
        "MediaSource": {
            "Id": "src-001",
            "TranscodingUrl": "/videos/abc/master.m3u8?&DeviceId=test&MediaSourceId=src-001&LiveStreamId=ls-001&api_key=baked",
            "Container": "ts",
            "LiveStreamId": "ls-001",
            "SupportsTranscoding": true
        }
    }
    """

    /// Fixture for the regression test: simulates a Jellyfin server that
    /// (despite our HLS-requesting profile) still returns a progressive
    /// `/stream` TranscodingUrl. The client must NOT silently rewrite this —
    /// the regression test asserts the path passes through untouched.
    private let progressiveTranscodingResponseJSON = """
    {
        "MediaSource": {
            "Id": "src-001",
            "TranscodingUrl": "/videos/abc/stream?&DeviceId=test&MediaSourceId=src-001&LiveStreamId=ls-001&api_key=baked",
            "Container": "ts",
            "LiveStreamId": "ls-001",
            "SupportsTranscoding": true
        }
    }
    """

    private let directStreamResponseJSON = """
    {
        "MediaSource": {
            "Id": "src-002",
            "Container": "ts",
            "LiveStreamId": "ls-002"
        }
    }
    """

    private let pluralResponseJSON = """
    {
        "MediaSources": [
            {
                "Id": "src-003",
                "Container": "ts"
            }
        ]
    }
    """

    /// Stub handler that dispatches by path: serves a fixed user from
    /// `/Users/Me` (so the actor's lazy userId resolution works) and the
    /// supplied playback JSON from `/Items/.../PlaybackInfo`.
    private func playbackStub(
        playbackJSON: String,
        capture: ((URLRequest) -> Void)? = nil
    ) -> (URLRequest) -> (HTTPURLResponse, Data) {
        return { request in
            let path = request.url?.path ?? ""
            if path == "/Users/Me" {
                return self.ok(self.userMeJSON, url: request.url!)
            }
            capture?(request)
            return self.ok(playbackJSON, url: request.url!)
        }
    }

    @Test func liveTvOpenStreamHitsCorrectPathAndMethod() async throws {
        var capturedRequest: URLRequest?
        let client = makeStubbedClient(handler: playbackStub(playbackJSON: transcodingResponseJSON) { req in
            capturedRequest = req
        })
        await client.setServerURL(serverURL)
        await client.setAccessToken("tok-test")
        _ = try await client.liveTvOpenStream(channelId: "ch-001")

        let req = try #require(capturedRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path == "/Items/ch-001/PlaybackInfo")
        let query = req.url?.query ?? ""
        #expect(query.contains("userId=user-001"))
        #expect(query.contains("autoOpenLiveStream=true"))
        #expect(query.contains("enableDirectPlay=true"))
        #expect(query.contains("enableDirectStream=true"))
        #expect(query.contains("enableTranscoding=true"))
        #expect(query.contains("allowVideoStreamCopy=true"))
        #expect(query.contains("allowAudioStreamCopy=true"))
    }

    @Test func liveTvOpenStreamSendsCorrectJSONBody() async throws {
        var capturedBody: Data?
        let client = makeStubbedClient(handler: playbackStub(playbackJSON: transcodingResponseJSON) { req in
            capturedBody = self.readBody(req)
        })
        await client.setServerURL(serverURL)
        await client.setAccessToken("tok-test")
        _ = try await client.liveTvOpenStream(channelId: "ch-007")

        let body = try #require(capturedBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        // PlaybackInfo body is just { DeviceProfile: ... } — no OpenToken.
        #expect(json["OpenToken"] == nil)
        let profile = try #require(json["DeviceProfile"] as? [String: Any])
        let directProfiles = try #require(profile["DirectPlayProfiles"] as? [[String: Any]])
        #expect(!directProfiles.isEmpty)
        #expect(directProfiles[0]["Container"] as? String == "ts,m2ts,mkv,mp4,m4v,mov")
        let transcodingProfiles = try #require(profile["TranscodingProfiles"] as? [[String: Any]])
        #expect(!transcodingProfiles.isEmpty)
        let tp = transcodingProfiles[0]
        #expect(tp["Protocol"] as? String == "hls")
        // The HLS transcode profile must request container=ts so Jellyfin
        // emits a real master.m3u8 URL for live TV (not the progressive
        // /videos/{id}/stream endpoint).
        #expect(tp["Container"] as? String == "ts")
        #expect(tp["VideoCodec"] as? String == "h264,hevc")
        #expect(tp["AudioCodec"] as? String == "aac,mp3,ac3,eac3")
        // MinSegments=1 (was 2 in Phase C) lets AVPlayer start as soon as
        // the first 10s segment is buffered, halving channel-change latency.
        // Network resilience comes from the player's auto-retry + reconnect
        // paths, not from a thicker initial buffer.
        #expect(tp["MinSegments"] as? Int == 1)
        // Must serialize as JSON bool, not string — Jellyfin's OpenAPI
        // schema declares this as boolean.
        #expect(tp["BreakOnNonKeyFrames"] as? Bool == true)
    }

    @Test func liveTvOpenStreamUsesServerSuppliedHlsTranscodingUrl() async throws {
        let client = makeStubbedClient(handler: playbackStub(playbackJSON: transcodingResponseJSON))
        await client.setServerURL(serverURL)
        await client.setAccessToken("tok-different-from-baked")
        let playback = try await client.liveTvOpenStream(channelId: "ch-001")

        let urlString = playback.playbackURL.absoluteString
        // The transcoding URL is resolved against the server, so the host is preserved.
        #expect(urlString.contains("192.168.1.50:8096"))
        // The server emits master.m3u8 natively now (driven by the device
        // profile's container=ts/protocol=hls). The client must honor the
        // server-supplied path verbatim.
        #expect(urlString.contains("/videos/abc/master.m3u8"))
        // Empty leading `?&` from Jellyfin's TranscodingUrl must be stripped —
        // the cleaned URL starts the query with a real param, not `?&`.
        #expect(!urlString.contains("master.m3u8?&"))
        #expect(urlString.contains("master.m3u8?DeviceId=test"))
        // The `?` must NOT be percent-encoded into `%3F`.
        #expect(!urlString.contains("%3F"))
        // `api_key=baked` came from Jellyfin's transcodingUrl. We must not have
        // appended `tok-different-from-baked` again — count the api_key occurrences.
        let apiKeyCount = urlString.components(separatedBy: "api_key=").count - 1
        #expect(apiKeyCount == 1)
        #expect(urlString.contains("api_key=baked"))
        #expect(!urlString.contains("api_key=tok-different-from-baked"))
        // Existing query params must be preserved
        #expect(urlString.contains("MediaSourceId=src-001"))
        #expect(urlString.contains("LiveStreamId=ls-001"))
        #expect(playback.liveStreamId == "ls-001")
    }

    /// Regression test: pins the behavior change that removed the client-side
    /// `/stream → /master.m3u8` path rewrite. If the server (despite our
    /// HLS-requesting profile) ever returns a progressive `/stream` URL, the
    /// client must pass it through untouched so AVPlayer fails loudly with
    /// the underlying problem rather than receiving a silently-broken HLS URL.
    /// The empty-name query cleanup still runs.
    @Test func liveTvOpenStreamPreservesProgressiveTranscodingUrl() async throws {
        let client = makeStubbedClient(handler: playbackStub(playbackJSON: progressiveTranscodingResponseJSON))
        await client.setServerURL(serverURL)
        await client.setAccessToken("tok-different-from-baked")
        let playback = try await client.liveTvOpenStream(channelId: "ch-001")

        let urlString = playback.playbackURL.absoluteString
        // Path must NOT be rewritten — server's /stream stays /stream.
        #expect(playback.playbackURL.path == "/videos/abc/stream")
        #expect(!urlString.contains("/master.m3u8"))
        // Empty-name query cleanup still ran (no `?&` after stream).
        #expect(!urlString.contains("stream?&"))
        #expect(urlString.contains("stream?DeviceId=test"))
        // No double api_key, no percent-encoded `?`.
        let apiKeyCount = urlString.components(separatedBy: "api_key=").count - 1
        #expect(apiKeyCount == 1)
        #expect(urlString.contains("api_key=baked"))
        #expect(!urlString.contains("%3F"))
        #expect(playback.liveStreamId == "ls-001")
    }

    @Test func liveTvOpenStreamFallsBackToDirectStreamUrl() async throws {
        let client = makeStubbedClient(handler: playbackStub(playbackJSON: directStreamResponseJSON))
        await client.setServerURL(serverURL)
        await client.setAccessToken("tok-fallback")
        let playback = try await client.liveTvOpenStream(channelId: "ch-002")

        let urlString = playback.playbackURL.absoluteString
        #expect(urlString.contains("192.168.1.50:8096"))
        #expect(urlString.contains("/Videos/src-002/stream.ts"))
        #expect(urlString.contains("MediaSourceId=src-002"))
        #expect(urlString.contains("static=true"))
        #expect(urlString.contains("api_key=tok-fallback"))
        #expect(urlString.contains("LiveStreamId=ls-002"))
        // Exactly one api_key in the URL
        let apiKeyCount = urlString.components(separatedBy: "api_key=").count - 1
        #expect(apiKeyCount == 1)
        // No percent-encoded ?
        #expect(!urlString.contains("%3F"))
        #expect(playback.liveStreamId == "ls-002")
    }

    @Test func liveTvOpenStreamUsesPluralMediaSourcesWhenSingularMissing() async throws {
        let client = makeStubbedClient(handler: playbackStub(playbackJSON: pluralResponseJSON))
        await client.setServerURL(serverURL)
        await client.setAccessToken("tok-plural")
        let playback = try await client.liveTvOpenStream(channelId: "ch-003")

        let urlString = playback.playbackURL.absoluteString
        #expect(urlString.contains("/Videos/src-003/stream.ts"))
        #expect(urlString.contains("api_key=tok-plural"))
    }

    @Test func liveTvOpenStreamUnauthenticatedWhenTokenMissing() async throws {
        let client = makeStubbedClient(handler: playbackStub(playbackJSON: transcodingResponseJSON))
        await client.setServerURL(serverURL)
        // Do NOT set access token
        do {
            _ = try await client.liveTvOpenStream(channelId: "ch-001")
            Issue.record("Expected unauthenticated to be thrown")
        } catch JellyfinError.unauthenticated {
            // expected
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    @Test func liveTvOpenStream401MapsToError() async throws {
        let client = makeStubbedClient { request in
            self.status(401, url: request.url!)
        }
        await client.setServerURL(serverURL)
        await client.setAccessToken("tok-test")
        do {
            _ = try await client.liveTvOpenStream(channelId: "ch-001")
            Issue.record("Expected unauthenticated to be thrown")
        } catch JellyfinError.unauthenticated {
            // expected
        } catch {
            Issue.record("Wrong error thrown: \(error)")
        }
    }

    /// Phase D: when forceTranscoding=true, enableDirectPlay flips to "false"
    /// and enableDirectStream also flips. Used by the player as a DirectPlay
    /// fallback when AVPlayer can't consume the direct-stream URL for live media.
    @Test func liveTvOpenStreamWithForceTranscodingDisablesDirectPlay() async throws {
        var capturedURL: URL?
        let client = makeStubbedClient(handler: playbackStub(playbackJSON: transcodingResponseJSON) { req in
            capturedURL = req.url
        })
        await client.setServerURL(serverURL)
        await client.setAccessToken("tok-test")
        _ = try await client.liveTvOpenStream(channelId: "ch-fallback", forceTranscoding: true)

        let url = try #require(capturedURL)
        let query = url.query ?? ""
        #expect(query.contains("enableDirectPlay=false"))
        #expect(query.contains("enableDirectStream=false"))
        #expect(query.contains("enableTranscoding=true"))
    }

    /// Phase D: liveTvCloseStream POSTs /LiveStreams/Close?liveStreamId=… so
    /// Jellyfin can kill the transcoder session immediately on player dismiss.
    @Test func liveTvCloseStreamSendsLiveStreamIdQueryParam() async throws {
        var capturedRequest: URLRequest?
        let client = makeStubbedClient { request in
            capturedRequest = request
            return self.ok("", url: request.url!)
        }
        await client.setServerURL(serverURL)
        await client.setAccessToken("tok-test")
        try await client.liveTvCloseStream(liveStreamId: "ls-zzz")

        let req = try #require(capturedRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path == "/LiveStreams/Close")
        let query = req.url?.query ?? ""
        #expect(query.contains("liveStreamId=ls-zzz"))
    }
}
