import SwiftUI
import NukeUI
import JellyfinAPI
import DesignSystem

/// Plex-style "Live TV Home." A focusable hero (currently-airing channel) on
/// top, then horizontally-scrolling shelves: Favorites / On Now / Movies /
/// Sports / News / Kids / Up Next / Recent Recordings.
public struct OnNowView: View {
    @Bindable var model: OnNowModel
    let onWatchChannel: (LiveTvChannel) -> Void
    let onSelectProgram: (LiveTvProgram) -> Void

    @FocusedValue(\.focusedOnNowChannel) private var focusedChannel
    @FocusedValue(\.focusedOnNowProgram) private var focusedProgram

    public init(
        model: OnNowModel,
        onWatchChannel: @escaping (LiveTvChannel) -> Void = { _ in },
        onSelectProgram: @escaping (LiveTvProgram) -> Void = { _ in }
    ) {
        self.model = model
        self.onWatchChannel = onWatchChannel
        self.onSelectProgram = onSelectProgram
    }

    private var isLoading: Bool {
        if case .loading = model.state { return true }
        return false
    }

    public var body: some View {
        Group {
            switch model.state {
            case .loading:
                OnNowSkeleton()
            case .loaded(let content):
                if content.isEmpty {
                    emptyState
                } else {
                    loaded(content: content)
                }
            case .failed(let message):
                failedView(message)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .background(LiveTVTheme.background)
        .task {
            if case .loading = model.state {
                await model.load()
            }
        }
    }

    @ViewBuilder
    private func loaded(content: OnNowContent) -> some View {
        let heroChannel = focusedChannel ?? content.heroChannel
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 50) {
                if let heroChannel {
                    OnNowHero(
                        channel: heroChannel,
                        focusedProgram: focusedProgram,
                        serverURL: content.serverURL,
                        onWatch: { onWatchChannel(heroChannel) },
                        onMoreInfo: {
                            if let program = heroChannel.currentProgram ?? focusedProgram {
                                onSelectProgram(program)
                            }
                        }
                    )
                }

                if !content.favorites.isEmpty {
                    ChannelShelf(
                        title: "Favorite Channels",
                        icon: "star.fill",
                        channels: content.favorites,
                        serverURL: content.serverURL,
                        onTap: onWatchChannel
                    )
                }

                if !content.onNow.isEmpty {
                    ChannelShelf(
                        title: "On Now",
                        icon: "dot.radiowaves.left.and.right",
                        channels: content.onNow,
                        serverURL: content.serverURL,
                        onTap: onWatchChannel
                    )
                }

                if !content.sports.isEmpty {
                    ChannelShelf(
                        title: "Sports",
                        icon: "sportscourt",
                        channels: content.sports,
                        serverURL: content.serverURL,
                        onTap: onWatchChannel
                    )
                }

                if !content.movies.isEmpty {
                    ChannelShelf(
                        title: "Movies",
                        icon: "film",
                        channels: content.movies,
                        serverURL: content.serverURL,
                        onTap: onWatchChannel
                    )
                }

                if !content.news.isEmpty {
                    ChannelShelf(
                        title: "News",
                        icon: "newspaper",
                        channels: content.news,
                        serverURL: content.serverURL,
                        onTap: onWatchChannel
                    )
                }

                if !content.kids.isEmpty {
                    ChannelShelf(
                        title: "Kids",
                        icon: "figure.and.child.holdinghands",
                        channels: content.kids,
                        serverURL: content.serverURL,
                        onTap: onWatchChannel
                    )
                }

                if !content.upNext.isEmpty {
                    ProgramShelf(
                        title: "Up Next",
                        icon: "calendar.badge.clock",
                        programs: content.upNext,
                        serverURL: content.serverURL,
                        onTap: onSelectProgram
                    )
                }

                if !content.recentRecordings.isEmpty {
                    RecordingShelf(
                        title: "Recordings",
                        icon: "record.circle",
                        items: content.recentRecordings,
                        serverURL: content.serverURL
                    )
                }

                Spacer(minLength: 60)
            }
            .padding(.vertical, 30)
        }
        .scrollClipDisabled()
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text("No live programming")
                .font(.title)
            Text("Configure a tuner or listings provider in Jellyfin to see channels here.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Reload") {
                Task { await model.load() }
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.title2)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await model.load() }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Hero

private struct OnNowHero: View {
    let channel: LiveTvChannel
    let focusedProgram: LiveTvProgram?
    let serverURL: URL
    let onWatch: () -> Void
    let onMoreInfo: () -> Void

    private var program: LiveTvProgram? {
        focusedProgram ?? channel.currentProgram
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop
            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    LiveBadge(label: "LIVE")
                    HStack(spacing: 8) {
                        ChannelLogoView(channel: channel, serverURL: serverURL, maxWidth: 240)
                            .frame(width: 64, height: 36)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(channel.name)
                                .font(.headline)
                            if let number = channel.number, !number.isEmpty {
                                Text("CH " + number)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                }

                Text(program?.name ?? channel.name)
                    .font(.system(size: 64, weight: .heavy))
                    .lineLimit(2)

                if let program {
                    HStack(spacing: 12) {
                        if let timeRange = LiveTvFormat.timeRange(start: program.startDate, end: program.endDate) {
                            Text(timeRange)
                                .font(.title3.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if let year = program.productionYear {
                            Text(String(year))
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        if let rating = program.officialRating {
                            Text(rating)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    if let overview = program.overview {
                        Text(overview)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: 980, alignment: .leading)
                    }
                }

                HStack(spacing: 16) {
                    HeroButton(title: "Watch", systemImage: "play.fill", isPrimary: true, action: onWatch)
                    if program != nil {
                        HeroButton(title: "More Info", systemImage: "info.circle", isPrimary: false, action: onMoreInfo)
                    }
                }
                .focusSection()
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 40)
            .padding(.top, 80)
        }
        .frame(height: 560)
        .containerRelativeFrame(.horizontal)
        .clipped()
        .animation(.easeInOut(duration: 0.35), value: program?.id)
        .animation(.easeInOut(duration: 0.35), value: channel.id)
    }

    @ViewBuilder
    private var backdrop: some View {
        if let url = program?.backdropURL(serverURL: serverURL, maxWidth: 1920) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    fallbackBackdrop
                }
            }
        } else {
            fallbackBackdrop
        }
    }

    private var fallbackBackdrop: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.4), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct HeroButton: View {
    let title: String
    let systemImage: String
    let isPrimary: Bool
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.headline)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(foreground)
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
    }

    private var background: Color {
        if isPrimary {
            return isFocused ? .white : .white.opacity(0.95)
        }
        return isFocused ? .white.opacity(0.30) : .white.opacity(0.18)
    }

    private var foreground: Color {
        isPrimary ? .black : .white
    }
}

// MARK: - Channel shelf (tile = channel logo + current program)

private struct ChannelShelf: View {
    let title: String
    let icon: String
    let channels: [LiveTvChannel]
    let serverURL: URL
    let onTap: (LiveTvChannel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ShelfHeader(title: title, icon: icon)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(channels) { channel in
                        ChannelTile(channel: channel, serverURL: serverURL) {
                            onTap(channel)
                        }
                    }
                }
                .padding(.horizontal, 60)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}

private struct ChannelTile: View {
    let channel: LiveTvChannel
    let serverURL: URL
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    backdrop
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    HStack(alignment: .top) {
                        ChannelLogoView(channel: channel, serverURL: serverURL, maxWidth: 240)
                            .frame(width: 56, height: 36)
                            .padding(8)
                            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                            .padding(10)
                        Spacer(minLength: 0)
                        if isAiringNow {
                            LiveBadge(label: "LIVE")
                                .padding(10)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Spacer(minLength: 0)
                        if let program = channel.currentProgram {
                            Text(program.name)
                                .font(.headline)
                                .lineLimit(2)
                                .foregroundStyle(.white)
                        } else {
                            Text(channel.name)
                                .font(.headline)
                                .lineLimit(1)
                                .foregroundStyle(.white)
                        }
                        if let timeRange = LiveTvFormat.timeRange(
                            start: channel.currentProgram?.startDate,
                            end: channel.currentProgram?.endDate
                        ) {
                            Text(timeRange)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(14)
                }
                .frame(width: 360, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 6) {
                    if let number = channel.number, !number.isEmpty {
                        Text(number)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(channel.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(isFocused ? .primary : .secondary)
                }
                .frame(width: 360, alignment: .leading)
            }
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
        .focusedValue(\.focusedOnNowChannel, isFocused ? channel : nil)
        .focusedValue(\.focusedOnNowProgram, isFocused ? channel.currentProgram : nil)
    }

    private var isAiringNow: Bool {
        guard let start = channel.currentProgram?.startDate,
              let end = channel.currentProgram?.endDate else { return false }
        let now = Date()
        return now >= start && now < end
    }

    @ViewBuilder
    private var backdrop: some View {
        if let url = channel.currentProgram?.tileImageURL(serverURL: serverURL, maxWidth: 720) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.5), Color.black.opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Program shelf (Up Next)

private struct ProgramShelf: View {
    let title: String
    let icon: String
    let programs: [LiveTvProgram]
    let serverURL: URL
    let onTap: (LiveTvProgram) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ShelfHeader(title: title, icon: icon)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(programs) { program in
                        ProgramTile(program: program, serverURL: serverURL) {
                            onTap(program)
                        }
                    }
                }
                .padding(.horizontal, 60)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}

private struct ProgramTile: View {
    let program: LiveTvProgram
    let serverURL: URL
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                tileBody
                    .frame(width: 320, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(program.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(isFocused ? .primary : .secondary)
                    .frame(width: 320, alignment: .leading)
                if let start = program.startDate {
                    Text(LiveTvFormat.timeFormatter.string(from: start))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: 320, alignment: .leading)
                }
            }
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
        .focusedValue(\.focusedOnNowProgram, isFocused ? program : nil)
    }

    @ViewBuilder
    private var tileBody: some View {
        if let url = program.tileImageURL(serverURL: serverURL, maxWidth: 640) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.6), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: "tv")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.65))
                Text(program.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Recording shelf

private struct RecordingShelf: View {
    let title: String
    let icon: String
    let items: [BaseItemDto]
    let serverURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ShelfHeader(title: title, icon: icon)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(items, id: \.id) { item in
                        RecordingTile(item: item, serverURL: serverURL)
                    }
                }
                .padding(.horizontal, 60)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}

private struct RecordingTile: View {
    let item: BaseItemDto
    let serverURL: URL

    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            // Recording playback — Phase 4 (post-MVP).
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Group {
                    if let url = item.imageURL(serverURL: serverURL, type: .thumb, maxWidth: 640)
                        ?? item.imageURL(serverURL: serverURL, type: .primary, maxWidth: 640)
                        ?? item.imageURL(serverURL: serverURL, type: .backdrop, maxWidth: 640) {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                fallback
                            }
                        }
                    } else {
                        fallback
                    }
                }
                .frame(width: 320, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(isFocused ? .primary : .secondary)
                    .frame(width: 320, alignment: .leading)
            }
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color.red.opacity(0.6), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "record.circle")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Shelf header

private struct ShelfHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
        }
        .padding(.horizontal, 60)
    }
}

// MARK: - Skeleton loading state

private struct OnNowSkeleton: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 50) {
                // Hero placeholder (matches OnNowHero's 560pt height)
                RoundedRectangle(cornerRadius: 0)
                    .fill(LiveTVTheme.surface)
                    .frame(maxWidth: .infinity)
                    .frame(height: 560)
                    .redacted(reason: .placeholder)

                // Shelf row 1
                skeletonShelf(tileWidth: 360, tileHeight: 200)

                // Shelf row 2
                skeletonShelf(tileWidth: 360, tileHeight: 200)

                Spacer(minLength: 60)
            }
            .padding(.vertical, 30)
        }
        .scrollClipDisabled()
        .focusable(false)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    @ViewBuilder
    private func skeletonShelf(tileWidth: CGFloat, tileHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // ShelfHeader placeholder
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LiveTVTheme.surface)
                    .frame(width: 20, height: 20)
                RoundedRectangle(cornerRadius: 4)
                    .fill(LiveTVTheme.surface)
                    .frame(width: 160, height: 22)
            }
            .padding(.horizontal, 60)
            .redacted(reason: .placeholder)

            // Tile row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LiveTVTheme.surface)
                            .frame(width: tileWidth, height: tileHeight)
                            .redacted(reason: .placeholder)
                    }
                }
                .padding(.horizontal, 60)
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: - Focus values

struct FocusedOnNowChannelKey: FocusedValueKey {
    typealias Value = LiveTvChannel
}

struct FocusedOnNowProgramKey: FocusedValueKey {
    typealias Value = LiveTvProgram
}

extension FocusedValues {
    var focusedOnNowChannel: LiveTvChannel? {
        get { self[FocusedOnNowChannelKey.self] }
        set { self[FocusedOnNowChannelKey.self] = newValue }
    }
    var focusedOnNowProgram: LiveTvProgram? {
        get { self[FocusedOnNowProgramKey.self] }
        set { self[FocusedOnNowProgramKey.self] = newValue }
    }
}
