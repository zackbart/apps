import SwiftUI
import NukeUI
import JellyfinAPI

/// Renders a channel's logo with a graceful "letter-bug" fallback when the
/// server has no image for the channel. Designed for Live TV guide rows and
/// channel-tile shelves; the parent decides the frame size.
public struct ChannelLogoView: View {
    public let channel: LiveTvChannel
    public let serverURL: URL
    public var maxWidth: Int

    public init(channel: LiveTvChannel, serverURL: URL, maxWidth: Int = 320) {
        self.channel = channel
        self.serverURL = serverURL
        self.maxWidth = maxWidth
    }

    public var body: some View {
        if let url = channel.logoURL(serverURL: serverURL, maxWidth: maxWidth) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        let initials = String(channel.name.prefix(2)).uppercased()
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [Color.accentColor.opacity(0.65), Color.accentColor.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text(initials)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(8)
        }
    }
}

/// Live red dot — pulses to communicate "this is happening right now."
public struct LiveBadge: View {
    public var label: String

    public init(label: String = "LIVE") {
        self.label = label
    }

    @State private var pulse = false

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(pulse ? 1.15 : 0.85)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            Text(label)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.black.opacity(0.5), in: Capsule())
        .onAppear { pulse = true }
    }
}

/// Compact start/end time string formatter for EPG cells.
public enum LiveTvFormat {
    public static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    public static func timeRange(start: Date?, end: Date?) -> String? {
        guard let start, let end else { return nil }
        return "\(timeFormatter.string(from: start)) – \(timeFormatter.string(from: end))"
    }

    public static func progressFraction(start: Date?, end: Date?, now: Date) -> Double? {
        guard let start, let end, end > start else { return nil }
        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        return max(0, min(1, elapsed / total))
    }
}
