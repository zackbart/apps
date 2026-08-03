import SwiftUI
import JellyfinAPI
import DesignSystem
import NukeUI

/// The Home tab, live-first: a full-bleed hero for the channel you were last
/// watching (falling back to the best on-now pick), then an "On Now" shelf of
/// typographic landscape cards with progress hairlines. Reuses `OnNowModel`'s
/// loaded content; the hero Watch button tunes straight in, Guide opens the
/// full grid.
public struct MarqueeHomeView: View {
    @Bindable var model: OnNowModel
    let lastWatchedChannelId: String?
    let onWatchChannel: (LiveTvChannel) -> Void
    let onOpenGuide: () -> Void

    public init(
        model: OnNowModel,
        lastWatchedChannelId: String? = nil,
        onWatchChannel: @escaping (LiveTvChannel) -> Void = { _ in },
        onOpenGuide: @escaping () -> Void = {}
    ) {
        self.model = model
        self.lastWatchedChannelId = lastWatchedChannelId
        self.onWatchChannel = onWatchChannel
        self.onOpenGuide = onOpenGuide
    }

    public var body: some View {
        ZStack {
            LiveTVTheme.background.ignoresSafeArea()
            switch model.state {
            case .loading:
                HomeSkeleton()
            case .failed(let message):
                MarqueeErrorView(message: message) {
                    Task { await model.load() }
                }
            case .loaded(let content):
                if content.isEmpty {
                    MarqueeErrorView(message: "Nothing is airing right now.", retryLabel: "Reload") {
                        Task { await model.load() }
                    }
                } else {
                    loaded(content)
                }
            }
        }
        .task {
            if case .loading = model.state { await model.load() }
        }
    }

    // MARK: - Loaded layout

    private func loaded(_ content: OnNowContent) -> some View {
        let hero = resolveHero(content)
        return ZStack(alignment: .bottomLeading) {
            backdrop(for: hero, serverURL: content.serverURL)
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                if let hero {
                    HomeHero(
                        channel: hero,
                        isLastWatched: hero.id == lastWatchedChannelId,
                        onWatch: { onWatchChannel(hero) },
                        onGuide: onOpenGuide
                    )
                    .padding(.horizontal, 80)
                }
                OnNowShelf(
                    channels: shelfChannels(content, hero: hero),
                    onWatchChannel: onWatchChannel
                )
                .padding(.top, 44)
                .padding(.bottom, 60)
            }
        }
    }

    /// Last-watched channel if it's still airing something we know about,
    /// otherwise the content's default hero pick.
    private func resolveHero(_ content: OnNowContent) -> LiveTvChannel? {
        if let id = lastWatchedChannelId {
            let pools = [content.onNow, content.favorites, content.movies, content.sports, content.news, content.kids]
            for pool in pools {
                if let match = pool.first(where: { $0.id == id }) { return match }
            }
        }
        return content.heroChannel
    }

    /// Shelf = on-now lineup (favorites first), hero excluded so the first
    /// card isn't a duplicate of the thing above it.
    private func shelfChannels(_ content: OnNowContent, hero: LiveTvChannel?) -> [LiveTvChannel] {
        let combined = content.favorites + content.onNow
        var seen = Set<String>()
        return combined.filter { channel in
            guard channel.id != hero?.id, !seen.contains(channel.id) else { return false }
            seen.insert(channel.id)
            return true
        }
    }

    @ViewBuilder
    private func backdrop(for hero: LiveTvChannel?, serverURL: URL) -> some View {
        GeometryReader { geo in
            ZStack {
                if let url = hero?.currentProgram?.backdropURL(serverURL: serverURL, maxWidth: 1920) {
                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .transition(.opacity)
                        } else {
                            Color.clear
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: hero?.id)
                }
                // Heavy monochrome scrims: keep the artwork present but quiet.
                LinearGradient(
                    stops: [
                        .init(color: LiveTVTheme.background.opacity(0.55), location: 0),
                        .init(color: LiveTVTheme.background.opacity(0.25), location: 0.3),
                        .init(color: LiveTVTheme.background.opacity(0.6), location: 0.55),
                        .init(color: LiveTVTheme.background.opacity(0.98), location: 0.85),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                LinearGradient(
                    colors: [LiveTVTheme.background.opacity(0.75), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Hero

private struct HomeHero: View {
    let channel: LiveTvChannel
    let isLastWatched: Bool
    let onWatch: () -> Void
    let onGuide: () -> Void

    var body: some View {
        let program = channel.currentProgram
        VStack(alignment: .leading, spacing: 0) {
            Text(kicker)
                .font(LiveTVTypography.kicker)
                .tracking(7)
                .textCase(.uppercase)
                .foregroundStyle(LiveTVTheme.secondaryText)
            Text(program?.name ?? channel.name)
                .font(LiveTVTypography.heroDisplay)
                .foregroundStyle(LiveTVTheme.text)
                .lineLimit(2)
                .padding(.top, 22)
            metaRow(program: program)
                .padding(.top, 18)
            HStack(spacing: 22) {
                MarqueeButton(title: "Watch", isPrimary: true, action: onWatch)
                MarqueeButton(title: "Guide", isPrimary: false, action: onGuide)
            }
            .padding(.top, 34)
            .focusSection()
        }
    }

    private var kicker: String {
        let prefix = isLastWatched ? "You were watching" : "On now"
        if let number = channel.number {
            return "\(prefix) · Channel \(number)"
        }
        return "\(prefix) · \(channel.name)"
    }

    @ViewBuilder
    private func metaRow(program: LiveTvProgram?) -> some View {
        HStack(spacing: 30) {
            Text(channel.name)
            if let range = LiveTvFormat.timeRange(start: program?.startDate, end: program?.endDate) {
                Text(range)
            }
            if program?.isLive == true {
                HStack(spacing: 10) {
                    Circle().fill(LiveTVTheme.live).frame(width: 9, height: 9)
                    Text("Live")
                }
            }
        }
        .font(.system(size: 24))
        .foregroundStyle(LiveTVTheme.secondaryText)
    }
}

/// Low-key hero action button: tracked uppercase label, primary = filled ink,
/// secondary = hairline outline. Focus handling stays native (.card).
private struct MarqueeButton: View {
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .tracking(5)
                .textCase(.uppercase)
                .foregroundStyle(isPrimary ? LiveTVTheme.background : LiveTVTheme.text)
                .padding(.horizontal, 44)
                .padding(.vertical, 18)
                .background(isPrimary ? LiveTVTheme.ink : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isPrimary ? Color.clear : LiveTVTheme.divider, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
    }
}

// MARK: - On Now shelf

private struct OnNowShelf: View {
    let channels: [LiveTvChannel]
    let onWatchChannel: (LiveTvChannel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .center, spacing: 28) {
                Text("On Now")
                    .font(LiveTVTypography.shelfLabel)
                    .foregroundStyle(LiveTVTheme.text)
                Rectangle()
                    .fill(LiveTVTheme.divider)
                    .frame(height: 1)
            }
            .padding(.horizontal, 80)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 36) {
                    ForEach(channels) { channel in
                        OnNowCard(channel: channel) {
                            onWatchChannel(channel)
                        }
                    }
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 16)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}

private struct OnNowCard: View {
    let channel: LiveTvChannel
    let action: () -> Void

    var body: some View {
        let program = channel.currentProgram
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(channel.number ?? "·")
                    .font(LiveTVTypography.serifChannelNumber)
                    .foregroundStyle(LiveTVTheme.secondaryText)
                Spacer(minLength: 14)
                Text(program?.name ?? channel.name)
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(LiveTVTheme.text)
                    .lineLimit(1)
                Text(caption(program: program))
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundStyle(LiveTVTheme.secondaryText)
                    .lineLimit(1)
                    .padding(.top, 10)
                progressHairline(program: program)
                    .padding(.top, 16)
            }
            .padding(26)
            .frame(width: 380, height: 214, alignment: .leading)
            .background(LiveTVTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(LiveTVTheme.ink.opacity(0.09), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel("\(channel.name), \(program?.name ?? "no program info")")
    }

    private func caption(program: LiveTvProgram?) -> String {
        if let end = program?.endDate {
            return "\(channel.name) · until \(LiveTvFormat.timeFormatter.string(from: end))"
        }
        return channel.name
    }

    @ViewBuilder
    private func progressHairline(program: LiveTvProgram?) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(LiveTVTheme.divider)
                        .frame(height: 1)
                    if let fraction = LiveTvFormat.progressFraction(
                        start: program?.startDate,
                        end: program?.endDate,
                        now: context.date
                    ) {
                        Rectangle()
                            .fill(LiveTVTheme.ink.opacity(0.65))
                            .frame(width: geo.size.width * fraction, height: 2)
                    }
                }
            }
            .frame(height: 2)
        }
    }
}

// MARK: - Skeleton

private struct HomeSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 24) {
                bar(width: 300, height: 20)
                bar(width: 760, height: 84)
                bar(width: 420, height: 22)
                HStack(spacing: 22) {
                    bar(width: 190, height: 58)
                    bar(width: 190, height: 58)
                }
            }
            .padding(.horizontal, 80)
            HStack(spacing: 36) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LiveTVTheme.surface)
                        .frame(width: 380, height: 214)
                }
            }
            .padding(.horizontal, 80)
            .padding(.top, 60)
            .padding(.bottom, 60)
        }
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
