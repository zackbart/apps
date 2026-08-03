import Foundation
import JellyfinAPI

/// Pure helper that returns the next/previous channel by channel number,
/// wrapping around at the ends. Channels with numeric `number` fields sort
/// ascending by that number; channels without a numeric number sort
/// lexicographically after all numeric channels.
public enum ChannelOrdering {
    /// Returns the channel sorted immediately after `current` in the canonical
    /// order, wrapping to the first channel if `current` is last. Returns nil
    /// if `channels` is empty or the current channel isn't in the list.
    public static func next(after current: LiveTvChannel, in channels: [LiveTvChannel]) -> LiveTvChannel? {
        let sorted = sortedByChannelNumber(channels)
        guard !sorted.isEmpty,
              let idx = sorted.firstIndex(where: { $0.id == current.id }) else { return nil }
        let nextIdx = (idx + 1) % sorted.count
        return sorted[nextIdx]
    }

    /// Returns the channel sorted immediately before `current`, wrapping to
    /// the last channel if `current` is first.
    public static func previous(before current: LiveTvChannel, in channels: [LiveTvChannel]) -> LiveTvChannel? {
        let sorted = sortedByChannelNumber(channels)
        guard !sorted.isEmpty,
              let idx = sorted.firstIndex(where: { $0.id == current.id }) else { return nil }
        let prevIdx = (idx - 1 + sorted.count) % sorted.count
        return sorted[prevIdx]
    }

    /// Sort channels by `number` numerically when possible, falling back to
    /// lexicographic compare for non-numeric numbers. Stable: ties broken by
    /// channel name.
    public static func sortedByChannelNumber(_ channels: [LiveTvChannel]) -> [LiveTvChannel] {
        channels.sorted { lhs, rhs in
            let lhsKey = sortKey(for: lhs)
            let rhsKey = sortKey(for: rhs)
            if lhsKey != rhsKey { return lhsKey < rhsKey }
            return lhs.name < rhs.name
        }
    }

    /// Numeric channels sort first by their integer value (e.g. "101" → 101).
    /// Non-numeric channels sort after all numeric channels by lexicographic
    /// compare on the original number string. Channels missing `number`
    /// entirely sort last by name.
    private static func sortKey(for channel: LiveTvChannel) -> String {
        guard let number = channel.number, !number.isEmpty else {
            // Triple-Z prefix puts these after even non-numeric channels.
            return "ZZZ\(channel.name)"
        }
        // Try to parse the leading numeric prefix (handles "101", "101.1", etc.)
        let leadingDigits = number.prefix { $0.isNumber || $0 == "." }
        if let value = Double(leadingDigits) {
            // Pad numeric value so string compare yields numeric order.
            // Width 12 covers any realistic channel number.
            return String(format: "0%011.4f", value)
        }
        // Z prefix puts non-numeric channels after all numeric ones, but
        // before number-missing channels.
        return "Z\(number)"
    }
}
