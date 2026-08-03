import Foundation
import Observation
import JellyfinAPI

@MainActor
@Observable
public final class HomeModel {
    public enum State: Equatable, Sendable {
        case loading
        case loaded(HomeContent)
        case failed(String)
    }

    public private(set) var state: State = .loading

    private let client: any JellyfinClientAPI

    public init(client: any JellyfinClientAPI) {
        self.client = client
    }

    public func load() async {
        state = .loading

        guard let serverURL = await client.currentServerURL() else {
            state = .failed("Not signed in")
            return
        }

        do {
            async let libraries = client.userViews()
            async let resumeItems = client.resumeItems(limit: 10)
            async let nextUpItems = client.nextUp(limit: 10)

            let (librariesResult, resumeResult, nextUpResult) = try await (libraries, resumeItems, nextUpItems)

            var latestPerLibrary: [String: [BaseItemDto]] = [:]
            try await withThrowingTaskGroup(of: (String, [BaseItemDto]).self) { group in
                for library in librariesResult {
                    let libraryId = library.id
                    group.addTask {
                        let latest = try await self.client.latestItems(parentId: libraryId, limit: 10)
                        return (libraryId, latest)
                    }
                }
                for try await (libraryId, latest) in group {
                    if !latest.isEmpty {
                        latestPerLibrary[libraryId] = latest
                    }
                }
            }

            let content = HomeContent(
                serverURL: serverURL,
                libraries: librariesResult,
                resumeItems: resumeResult,
                nextUp: nextUpResult,
                latestPerLibrary: latestPerLibrary
            )

            state = .loaded(content)
        } catch JellyfinError.network {
            state = .failed("Couldn't reach the server.")
        } catch JellyfinError.unauthenticated {
            state = .failed("Session expired. Please sign in again.")
        } catch {
            state = .failed("Something went wrong: \(error)")
        }
    }
}

public struct HomeContent: Equatable, Sendable {
    public let serverURL: URL
    public let libraries: [BaseItemDto]
    public let resumeItems: [BaseItemDto]
    public let nextUp: [BaseItemDto]
    public let latestPerLibrary: [String: [BaseItemDto]]

    public init(
        serverURL: URL,
        libraries: [BaseItemDto],
        resumeItems: [BaseItemDto],
        nextUp: [BaseItemDto],
        latestPerLibrary: [String: [BaseItemDto]]
    ) {
        self.serverURL = serverURL
        self.libraries = libraries
        self.resumeItems = resumeItems
        self.nextUp = nextUp
        self.latestPerLibrary = latestPerLibrary
    }
}