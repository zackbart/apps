import SwiftUI
import JellyfinAPI
import DesignSystem

/// The Live tab: a typographic playbill. Big now-playing panel on the left
/// reflecting the focused channel; vertical channel list on the right —
/// serif-italic number, channel name, current program. Select to tune.
public struct PlaybillView: View {
    @Bindable var model: PlaybillModel
    let lastWatchedChannelId: String?
    let onWatchChannel: (LiveTvChannel) -> Void

    @FocusedValue(\.playbillChannel) private var focusedChannel: LiveTvChannel?

    public init(
        model: PlaybillModel,
        lastWatchedChannelId: String? = nil,
        onWatchChannel: @escaping (LiveTvChannel) -> Void = { _ in }
    ) {
        self.model = model
        self.lastWatchedChannelId = lastWatchedChannelId
        self.onWatchChannel = onWatchChannel
    }

    public var body: some View {
        ZStack {
            LiveTVTheme.background.ignoresSafeArea()
            switch model.state {
            case .loading:
                PlaybillSkeleton()
            case .failed(let message):
                MarqueeErrorView(message: message) {
                    Task { await model.load() }
                }
            case .loaded(let channels):
                if channels.isEmpty {
                    MarqueeErrorView(message: "No live channels on this server.", retryLabel: "Reload") {
                        Task { await model.load() }
                    }
                } else {
                    loaded(channels)
                }
            }
        }
        .task {
            if case .loading = model.state { await model.load() }
        }
    }

    private func loaded(_ channels: [LiveTvChannel]) -> some View {
        let displayed = focusedChannel
            ?? channels.first(where: { $0.id == lastWatchedChannelId })
            ?? channels[0]
        return HStack(alignment: .bottom, spacing: 80) {
            NowPlayingPanel(channel: displayed)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            channelList(channels)
                .frame(width: 700)
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 60)
        .animation(.easeInOut(duration: 0.18), value: displayed.id)
    }

    private func channelList(_ channels: [LiveTvChannel]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 4) {
                ForEach(channels) { channel in
                    PlaybillRow(
                        channel: channel,
                        isLastWatched: channel.id == lastWatchedChannelId
                    ) {
                        onWatchChannel(channel)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .focusSection()
    }
}

// MARK: - Now-playing panel

private struct NowPlayingPanel: View {
    let channel: LiveTvChannel

    var body: some View {
        let program = channel.currentProgram
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Circle()
                    .fill(LiveTVTheme.live)
                    .frame(width: 12, height: 12)
                Text("On Air · \(channel.name)")
                    .font(LiveTVTypography.kicker)
                    .tracking(7)
                    .textCase(.uppercase)
                    .foregroundStyle(LiveTVTheme.secondaryText)
            }
            Text(program?.name ?? channel.name)
                .font(LiveTVTypography.playbillTitle)
                .foregroundStyle(LiveTVTheme.text)
                .lineLimit(3)
                .padding(.top, 26)
            if let range = LiveTvFormat.timeRange(start: program?.startDate, end: program?.endDate) {
                Text(range)
                    .font(LiveTVTypography.programTime)
                    .foregroundStyle(LiveTVTheme.secondaryText)
                    .padding(.top, 14)
            }
            progress(program: program)
                .padding(.top, 44)
        }
    }

    @ViewBuilder
    private func progress(program: LiveTvProgram?) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if let fraction = LiveTvFormat.progressFraction(
                start: program?.startDate,
                end: program?.endDate,
                now: context.date
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(LiveTVTheme.divider)
                                .frame(height: 1)
                            Rectangle()
                                .fill(LiveTVTheme.ink.opacity(0.75))
                                .frame(width: geo.size.width * fraction, height: 2)
                        }
                    }
                    .frame(height: 2)
                    HStack {
                        timeText(program?.startDate)
                        Spacer()
                        timeText(program?.endDate)
                    }
                }
            }
        }
    }

    private func timeText(_ date: Date?) -> some View {
        Text(date.map { LiveTvFormat.timeFormatter.string(from: $0) } ?? "")
            .font(.caption.monospacedDigit())
            .foregroundStyle(LiveTVTheme.secondaryText)
            .tracking(2)
    }
}

// MARK: - Channel row

private struct PlaybillRow: View {
    let channel: LiveTvChannel
    let isLastWatched: Bool
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                Text(channel.number ?? "·")
                    .font(LiveTVTypography.serifChannelNumber)
                    .foregroundStyle(isFocused ? LiveTVTheme.text : LiveTVTheme.secondaryText)
                    .frame(width: 70, alignment: .trailing)
                Text(channel.name)
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(LiveTVTheme.text)
                    .lineLimit(1)
                Spacer(minLength: 20)
                Text(channel.currentProgram?.name ?? "")
                    .font(.system(size: 21))
                    .foregroundStyle(LiveTVTheme.secondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
        .focusedValue(\.playbillChannel, isFocused ? channel : nil)
        .accessibilityLabel("\(channel.name), \(channel.currentProgram?.name ?? "no program info")")
    }
}

// MARK: - Skeleton

private struct PlaybillSkeleton: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 80) {
            VStack(alignment: .leading, spacing: 24) {
                bar(width: 220, height: 20)
                bar(width: 560, height: 64)
                bar(width: 300, height: 20)
                Rectangle().fill(LiveTVTheme.divider).frame(height: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            VStack(spacing: 16) {
                ForEach(0..<8, id: \.self) { _ in
                    bar(width: 640, height: 52)
                }
            }
            .frame(width: 700)
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 60)
        .redacted(reason: .placeholder)
        .focusable(false)
        .allowsHitTesting(false)
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(LiveTVTheme.surface)
            .frame(width: width, height: height)
    }
}

// MARK: - Shared error view

/// Minimal monochrome error state shared by the Marquee screens.
struct MarqueeErrorView: View {
    let message: String
    var retryLabel: String = "Try Again"
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text(message)
                .font(LiveTVTypography.strongTitle)
                .foregroundStyle(LiveTVTheme.text)
                .multilineTextAlignment(.center)
            Button(retryLabel, action: onRetry)
                #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
                .font(LiveTVTypography.kicker)
        }
        .padding(80)
    }
}

// MARK: - Focused-value plumbing

public struct FocusedPlaybillChannelKey: FocusedValueKey {
    public typealias Value = LiveTvChannel
}

public extension FocusedValues {
    var playbillChannel: LiveTvChannel? {
        get { self[FocusedPlaybillChannelKey.self] }
        set { self[FocusedPlaybillChannelKey.self] = newValue }
    }
}
