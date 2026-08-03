import Testing
import Foundation
import JellyfinAPI
@testable import LiveTV

@Suite("ChannelOrdering")
struct ChannelOrderingTests {

    private func ch(_ id: String, number: String? = nil, name: String = "Channel") -> LiveTvChannel {
        LiveTvChannel(id: id, name: name, number: number)
    }

    @Test func sortsByNumericChannelNumberAscending() {
        let unsorted = [ch("c", number: "103"), ch("a", number: "101"), ch("b", number: "102")]
        let sorted = ChannelOrdering.sortedByChannelNumber(unsorted)
        #expect(sorted.map(\.id) == ["a", "b", "c"])
    }

    @Test func nonNumericChannelsSortAfterNumeric() {
        let unsorted = [ch("a", number: "ABC"), ch("b", number: "101"), ch("c", number: "201")]
        let sorted = ChannelOrdering.sortedByChannelNumber(unsorted)
        #expect(sorted.map(\.id) == ["b", "c", "a"])
    }

    @Test func channelsMissingNumberSortLastByName() {
        let unsorted = [
            ch("a", number: nil, name: "Zulu"),
            ch("b", number: "101", name: "Alpha"),
            ch("c", number: nil, name: "Bravo"),
        ]
        let sorted = ChannelOrdering.sortedByChannelNumber(unsorted)
        #expect(sorted.map(\.id) == ["b", "c", "a"])
    }

    @Test func nextWrapsAroundAtEnd() {
        let channels = [ch("a", number: "101"), ch("b", number: "102"), ch("c", number: "103")]
        let next = ChannelOrdering.next(after: channels[2], in: channels)
        #expect(next?.id == "a")
    }

    @Test func previousWrapsAroundAtStart() {
        let channels = [ch("a", number: "101"), ch("b", number: "102"), ch("c", number: "103")]
        let prev = ChannelOrdering.previous(before: channels[0], in: channels)
        #expect(prev?.id == "c")
    }

    @Test func nextOnSingleChannelReturnsItself() {
        let channels = [ch("a", number: "101")]
        let next = ChannelOrdering.next(after: channels[0], in: channels)
        #expect(next?.id == "a")
    }

    @Test func nextWithCurrentNotInListReturnsNil() {
        let channels = [ch("a", number: "101"), ch("b", number: "102")]
        let phantom = ch("z", number: "999")
        let next = ChannelOrdering.next(after: phantom, in: channels)
        #expect(next == nil)
    }

    @Test func nextOnEmptyChannelsReturnsNil() {
        let phantom = ch("a", number: "101")
        let next = ChannelOrdering.next(after: phantom, in: [])
        #expect(next == nil)
    }

    @Test func decimalChannelNumbersSortInOrder() {
        // 101.1 should sort between 101 and 102, not with strings starting with "1".
        let unsorted = [
            ch("a", number: "102"),
            ch("b", number: "101.1"),
            ch("c", number: "101"),
        ]
        let sorted = ChannelOrdering.sortedByChannelNumber(unsorted)
        #expect(sorted.map(\.id) == ["c", "b", "a"])
    }

    @Test func nextStepsByChannelNumberOrderNotInputOrder() {
        // Input order is unsorted; next() should follow channel-number order.
        let channels = [ch("c", number: "103"), ch("a", number: "101"), ch("b", number: "102")]
        let next = ChannelOrdering.next(after: channels[1], in: channels) // after "a" / 101
        #expect(next?.id == "b") // → 102
    }
}
