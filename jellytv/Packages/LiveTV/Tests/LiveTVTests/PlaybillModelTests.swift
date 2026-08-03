import Testing
import Foundation
@testable import LiveTV
import JellyfinAPI

@MainActor
@Suite("PlaybillModel")
struct PlaybillModelTests {
    private func makeChannel(id: String, name: String, number: String?) -> LiveTvChannel {
        LiveTvChannel(id: id, name: name, number: number)
    }

    @Test
    func loadSortsChannelsByNumberAndRequestsCurrentProgram() async {
        let fake = FakeJellyfinClient()
        fake.liveTvFilteredChannelsResult = .success([
            makeChannel(id: "b", name: "Beta", number: "21"),
            makeChannel(id: "a", name: "Alpha", number: "2"),
            makeChannel(id: "c", name: "Gamma", number: "7"),
        ])

        let store = EPGStore(client: fake)
        let model = PlaybillModel(store: store)
        await model.load()

        guard case .loaded(let channels) = model.state else {
            Issue.record("Expected loaded state, got \(model.state)")
            return
        }
        #expect(channels.map(\.number) == ["2", "7", "21"])
        #expect(fake.lastAddCurrentProgram == true)
    }

    @Test
    func loadFailureSurfacesMessage() async {
        let fake = FakeJellyfinClient()
        fake.liveTvFilteredChannelsResult = .failure(JellyfinError.network(URLError(.notConnectedToInternet)))

        let store = EPGStore(client: fake)
        let model = PlaybillModel(store: store)
        await model.load()

        guard case .failed(let message) = model.state else {
            Issue.record("Expected failed state, got \(model.state)")
            return
        }
        #expect(message == "Couldn't reach the server.")
    }
}
