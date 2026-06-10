import SwiftUI
import NukeUI
import JellyfinAPI
import DesignSystem

public struct RecordingsView: View {
    @Bindable var model: RecordingsModel

    public init(model: RecordingsModel) {
        self.model = model
    }

    private var isLoading: Bool {
        if case .loading = model.state { return true }
        return false
    }

    public var body: some View {
        Group {
            switch model.state {
            case .loading:
                RecordingsSkeleton()
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
        .task {
            if case .loading = model.state {
                await model.load()
            }
        }
    }

    @ViewBuilder
    private func loaded(content: RecordingsContent) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 50) {
                if !content.recording.isEmpty {
                    RecordingGrid(
                        title: "Recording Now",
                        icon: "record.circle.fill",
                        accent: .red,
                        items: content.recording,
                        serverURL: content.serverURL,
                        onDelete: { item in Task { await model.deleteRecording(item) } }
                    )
                }
                if !content.scheduled.isEmpty {
                    ScheduledSection(
                        timers: content.scheduled,
                        serverURL: content.serverURL,
                        onCancel: { timer in Task { await model.cancelTimer(timer) } }
                    )
                }
                if !content.series.isEmpty {
                    SeriesSection(
                        timers: content.series,
                        serverURL: content.serverURL,
                        onCancel: { timer in Task { await model.cancelSeriesTimer(timer) } }
                    )
                }
                if !content.library.isEmpty {
                    RecordingGrid(
                        title: "Recorded",
                        icon: "tray.full",
                        accent: .secondary,
                        items: content.library,
                        serverURL: content.serverURL,
                        onDelete: { item in Task { await model.deleteRecording(item) } }
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
            Image(systemName: "record.circle")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text("No recordings yet")
                .font(.title)
            Text("Schedule a recording from the Guide or a program detail to see it here.")
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

// MARK: - Skeleton loading state

private struct RecordingsSkeleton: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 50) {
                skeletonSection
                skeletonSection
                Spacer(minLength: 60)
            }
            .padding(.vertical, 30)
        }
        .scrollClipDisabled()
        .focusable(false)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var skeletonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LiveTVTheme.surface)
                            .frame(width: 360, height: 200)
                            .redacted(reason: .placeholder)
                    }
                }
                .padding(.horizontal, 60)
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: - Sections

private struct RecordingGrid: View {
    let title: String
    let icon: String
    let accent: Color
    let items: [BaseItemDto]
    let serverURL: URL
    let onDelete: (BaseItemDto) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                Text(title)
                    .font(.title3.weight(.semibold))
            }
            .padding(.horizontal, 60)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(items, id: \.id) { item in
                        RecordingCard(item: item, serverURL: serverURL, onDelete: { onDelete(item) })
                    }
                }
                .padding(.horizontal, 60)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}

private struct RecordingCard: View {
    let item: BaseItemDto
    let serverURL: URL
    let onDelete: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 10) {
                Group {
                    if let url = item.imageURL(serverURL: serverURL, type: .thumb, maxWidth: 720)
                        ?? item.imageURL(serverURL: serverURL, type: .primary, maxWidth: 720)
                        ?? item.imageURL(serverURL: serverURL, type: .backdrop, maxWidth: 720) {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                fallback
                            }
                        }
                    } else {
                        fallback
                    }
                }
                .frame(width: 360, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(isFocused ? .primary : .secondary)
                    .frame(width: 360, alignment: .leading)
            }
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete Recording", systemImage: "trash")
            }
        }
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color.red.opacity(0.5), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "record.circle")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

private struct ScheduledSection: View {
    let timers: [TimerInfoDto]
    let serverURL: URL
    let onCancel: (TimerInfoDto) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.orange)
                Text("Scheduled")
                    .font(.title3.weight(.semibold))
            }
            .padding(.horizontal, 60)

            VStack(spacing: 8) {
                ForEach(timers) { timer in
                    TimerRow(timer: timer, serverURL: serverURL, onCancel: { onCancel(timer) })
                }
            }
            .padding(.horizontal, 60)
        }
        .focusSection()
    }
}

private struct TimerRow: View {
    let timer: TimerInfoDto
    let serverURL: URL
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    private var timerSubtitle: String {
        var parts: [String] = []
        if let channelName = timer.channelName, !channelName.isEmpty {
            parts.append(channelName)
        }
        if let timeRange = LiveTvFormat.timeRange(start: timer.startDate, end: timer.endDate) {
            parts.append(timeRange)
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onCancel) {
            HStack(alignment: .center, spacing: 16) {
                channelLogo
                    .frame(width: 60, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(timer.name ?? "Untitled")
                        .font(.headline)
                        .lineLimit(1)
                    Text(timerSubtitle)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Cancel")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(isFocused ? 0.2 : 0.08), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(isFocused ? 0.12 : 0.04))
            )
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
    }

    @ViewBuilder
    private var channelLogo: some View {
        if let channelId = timer.channelId, let tag = timer.channelPrimaryImageTag,
           let url = JellyfinImage.url(
               serverURL: serverURL,
               itemId: channelId,
               type: .primary,
               tag: tag,
               maxWidth: 240
           ) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fit)
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Image(systemName: "tv")
            .font(.title3)
            .foregroundStyle(.secondary)
    }
}

private struct SeriesSection: View {
    let timers: [SeriesTimerInfoDto]
    let serverURL: URL
    let onCancel: (SeriesTimerInfoDto) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.stack.badge.play")
                    .foregroundStyle(.purple)
                Text("Series Recordings")
                    .font(.title3.weight(.semibold))
            }
            .padding(.horizontal, 60)

            VStack(spacing: 8) {
                ForEach(timers) { timer in
                    SeriesRow(timer: timer, onCancel: { onCancel(timer) })
                }
            }
            .padding(.horizontal, 60)
        }
        .focusSection()
    }
}

private struct SeriesRow: View {
    let timer: SeriesTimerInfoDto
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    private var seriesSubtitle: String {
        var parts: [String] = []
        if timer.recordAnyChannel == true {
            parts.append("Any channel")
        } else if let channelName = timer.channelName {
            parts.append(channelName)
        }
        if timer.recordAnyTime == true { parts.append("Any time") }
        if timer.recordNewOnly == true { parts.append("New only") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onCancel) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "rectangle.stack.badge.play")
                    .font(.title3)
                    .foregroundStyle(.purple)
                    .frame(width: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text(timer.name ?? "Series")
                        .font(.headline)
                        .lineLimit(1)
                    Text(seriesSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Cancel")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(isFocused ? 0.2 : 0.08), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(isFocused ? 0.12 : 0.04))
            )
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
    }
}
