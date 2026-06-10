import SwiftUI
import JellyfinAPI
import DesignSystem

/// Plex-style EPG guide. Channels run as rows; the time grid runs as a
/// horizontally-scrolling lane on the right. Programs are focusable so users
/// can drill into a `ProgramDetailView` from the guide. A category-filter
/// pill bar at the top scopes the channel list (All / Favorites / Movies /
/// Sports / News / Kids).
///
/// Selection is callback-driven so this view can be embedded inside the
/// `LiveTVRootView` tab shell, which centralizes player + detail
/// presentation.
public struct GuideView: View {
    @Bindable var model: GuideModel
    let onWatchChannel: (LiveTvChannel) -> Void
    let onSelectProgram: (LiveTvProgram) -> Void
    @Binding var lastWatchedChannelId: String?

    public init(
        model: GuideModel,
        onWatchChannel: @escaping (LiveTvChannel) -> Void = { _ in },
        onSelectProgram: @escaping (LiveTvProgram) -> Void = { _ in },
        lastWatchedChannelId: Binding<String?> = .constant(nil)
    ) {
        self.model = model
        self.onWatchChannel = onWatchChannel
        self.onSelectProgram = onSelectProgram
        self._lastWatchedChannelId = lastWatchedChannelId
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CategoryFilterBar(
                selected: model.categoryFilter,
                onSelect: { filter in
                    Task { await model.applyFilter(filter) }
                }
            )
            .padding(.horizontal, 60)
            .padding(.top, 30)
            .padding(.bottom, 16)

            content
        }
        .task {
            if case .loading = model.state {
                await model.load()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch model.state {
            case .loading:
                loadingState
            case .loaded(let snapshot):
                if snapshot.isEmpty {
                    emptyState
                } else {
                    GuideGridView(
                        content: snapshot,
                        onWatchChannel: onWatchChannel,
                        onSelectProgram: onSelectProgram,
                        lastWatchedChannelId: $lastWatchedChannelId
                    )
                }
            case .failed(let message):
                failedView(message)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }

    private var isLoading: Bool {
        if case .loading = model.state { return true }
        return false
    }

    private var loadingState: some View {
        GuideSkeletonView()
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "tv.slash")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text("No channels match this filter")
                .font(.title)
            Text("Try a different category, or check that your Jellyfin server has Live TV configured.")
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

// MARK: - Guide skeleton

private struct GuideSkeletonView: View {
    private let rowCount = 8

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                // Channel column placeholder
                channelColumnSkeleton

                // Program lane placeholder
                programLaneSkeleton
            }
        }
        .scrollClipDisabled()
        .focusable(false)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var channelColumnSkeleton: some View {
        VStack(spacing: 0) {
            // Time header spacer
            Color.clear.frame(height: GuideLayout.timeHeaderHeight)
            ForEach(0..<rowCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(LiveTVTheme.surface)
                    .frame(
                        width: GuideLayout.channelColumnWidth - 24,
                        height: GuideLayout.rowHeight - 16
                    )
                    .redacted(reason: .placeholder)
                    .padding(.horizontal, 12)
                    .frame(height: GuideLayout.rowHeight)
            }
        }
        .frame(width: GuideLayout.channelColumnWidth)
    }

    private var programLaneSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Time header placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(LiveTVTheme.surface)
                .frame(height: GuideLayout.timeHeaderHeight - 16)
                .redacted(reason: .placeholder)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(0..<rowCount, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { cellIndex in
                        let width: CGFloat = cellIndex % 3 == 0 ? 320 : 200
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LiveTVTheme.surface)
                            .frame(width: width, height: GuideLayout.rowHeight - 16)
                            .redacted(reason: .placeholder)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: GuideLayout.rowHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
