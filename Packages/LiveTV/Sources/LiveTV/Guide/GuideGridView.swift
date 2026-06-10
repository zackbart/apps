import SwiftUI
import NukeUI
import JellyfinAPI
import DesignSystem

/// The actual EPG grid: sticky channel column + horizontally-scrolling time
/// grid + a sticky "focused program" detail strip at the bottom that shows
/// the title, time, and overview of whatever cell currently has focus.
struct GuideGridView: View {
    let content: GuideContent
    let onWatchChannel: (LiveTvChannel) -> Void
    let onSelectProgram: (LiveTvProgram) -> Void
    @Binding var lastWatchedChannelId: String?

    @FocusedValue(\.focusedGuideProgram) private var focusedProgram
    @FocusedValue(\.focusedGuideChannel) private var focusedChannel
    @FocusState private var focusedChannelId: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        channelColumn
                        programArea
                    }
                }
                .scrollClipDisabled()
                .onChange(of: lastWatchedChannelId) { _, newId in
                    guard let newId else { return }
                    Task { @MainActor in
                        // Let SwiftUI render the dismissed-to view first.
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(newId, anchor: .center)
                        }
                        focusedChannelId = newId
                    }
                }
            }

            FocusedProgramFooter(
                program: focusedProgram,
                channel: focusedChannel,
                serverURL: content.serverURL
            )
        }
        .background(LiveTVTheme.background)
    }

    // MARK: - Channel column

    private var channelColumn: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: GuideLayout.timeHeaderHeight)
            ForEach(content.channels) { channel in
                ChannelRowHeader(
                    channel: channel,
                    serverURL: content.serverURL,
                    onTap: { onWatchChannel(channel) }
                )
                .frame(height: GuideLayout.rowHeight)
                // Inset the cell so .buttonStyle(.card)'s focus scale (~1.1×)
                // stays inside the column instead of overflowing into the
                // program grid on the right.
                .padding(.horizontal, 12)
                .focused($focusedChannelId, equals: channel.id)
                .id(channel.id)
            }
        }
        .frame(width: GuideLayout.channelColumnWidth)
        .focusSection()
    }

    // MARK: - Program area

    private var programArea: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                TimeHeader(windowStart: content.windowStart, windowEnd: content.windowEnd)
                    .frame(height: GuideLayout.timeHeaderHeight)
                ForEach(content.channels) { channel in
                    GuideChannelLane(
                        channel: channel,
                        programs: content.programs(for: channel.id),
                        windowStart: content.windowStart,
                        windowEnd: content.windowEnd,
                        onSelectProgram: onSelectProgram
                    )
                }
            }
            .overlay(alignment: .topLeading) {
                nowLine(windowStart: content.windowStart)
            }
        }
        .scrollClipDisabled()
    }

    /// Vertical "now" indicator. Wrapped in `TimelineView` so the line position
    /// updates once per minute. Critical: only the line itself is inside the
    /// timeline closure — the program grid is a sibling, so timeline ticks
    /// don't rebuild program cells (which would drop tvOS focus).
    ///
    /// Phase D: thicker (5pt), amber→broadcast-red gradient, with a 1.2s
    /// auto-reversing opacity pulse so the live edge feels alive.
    private func nowLine(windowStart: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let secondsSinceStart = context.date.timeIntervalSince(windowStart)
            let x = GuideLayout.offset(forSecondsSinceWindowStart: secondsSinceStart)
            NowLineMarker()
                .offset(x: x - 2.5)
                .allowsHitTesting(false)
        }
    }
}

/// Pulsing now-line marker — separated into its own view so the
/// auto-reversing animation lives next to the layer it animates without
/// the parent TimelineView restarting it on the periodic tick.
private struct NowLineMarker: View {
    @State private var pulsing: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: GuideLayout.timeHeaderHeight)
            Rectangle()
                .fill(LinearGradient(
                    colors: [LiveTVTheme.accent, LiveTVTheme.live],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 5)
                .frame(maxHeight: .infinity)
                .opacity(pulsing ? 1.0 : 0.6)
                .shadow(color: LiveTVTheme.live.opacity(0.7), radius: 12, x: 0, y: 0)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: pulsing
                )
        }
        .onAppear { pulsing = true }
    }
}

// MARK: - Channel row header (left column)

private struct ChannelRowHeader: View {
    let channel: LiveTvChannel
    let serverURL: URL
    let onTap: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ChannelLogoView(channel: channel, serverURL: serverURL, maxWidth: 240)
                    .frame(width: 64, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    if let number = channel.number, !number.isEmpty {
                        Text(number)
                            .font(LiveTVTypography.channelNumber)
                            .foregroundStyle(LiveTVTheme.accent)
                    }
                    Text(channel.name)
                        .font(LiveTVTypography.channelName)
                        .lineLimit(1)
                        .foregroundStyle(isFocused ? LiveTVTheme.text : LiveTVTheme.secondaryText)
                }
                Spacer(minLength: 0)
                if channel.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(LiveTVTheme.accent)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
        .focusedValue(\.focusedGuideChannel, isFocused ? channel : nil)
    }
}

// MARK: - Time header

private struct TimeHeader: View {
    let windowStart: Date
    let windowEnd: Date

    var body: some View {
        let slots = halfHourSlots(from: windowStart, to: windowEnd)
        ZStack(alignment: .topLeading) {
            ForEach(slots, id: \.self) { slot in
                let offset = GuideLayout.offset(
                    forSecondsSinceWindowStart: slot.timeIntervalSince(windowStart)
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(LiveTvFormat.timeFormatter.string(from: slot))
                        .font(LiveTVTypography.timeLabel)
                        .foregroundStyle(LiveTVTheme.text)
                    Rectangle()
                        .fill(LiveTVTheme.divider)
                        .frame(width: 1, height: 10)
                }
                .offset(x: offset, y: 16)
            }
        }
        .frame(width: totalWidth, alignment: .topLeading)
    }

    private var totalWidth: CGFloat {
        let minutes = windowEnd.timeIntervalSince(windowStart) / 60.0
        return CGFloat(minutes) * GuideLayout.pixelsPerMinute
    }

    private func halfHourSlots(from start: Date, to end: Date) -> [Date] {
        var slots: [Date] = []
        let calendar = Calendar(identifier: .gregorian)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        var rounded = calendar.date(from: comps) ?? start
        if let minute = comps.minute, minute > 0 && minute < 30 {
            rounded = rounded.addingTimeInterval(TimeInterval((30 - minute) * 60))
        } else if let minute = comps.minute, minute > 30 {
            rounded = rounded.addingTimeInterval(TimeInterval((60 - minute) * 60))
        }
        var slot = rounded
        while slot < end {
            slots.append(slot)
            slot = slot.addingTimeInterval(30 * 60)
        }
        return slots
    }
}

// MARK: - Single channel lane (row of program cells)

private struct GuideChannelLane: View {
    let channel: LiveTvChannel
    let programs: [LiveTvProgram]
    let windowStart: Date
    let windowEnd: Date
    let onSelectProgram: (LiveTvProgram) -> Void

    var body: some View {
        LazyHStack(alignment: .top, spacing: 0) {
            if programs.isEmpty {
                emptyLane
            } else {
                ForEach(programs) { program in
                    cell(for: program)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: GuideLayout.rowHeight, alignment: .topLeading)
        .focusSection()
    }

    @ViewBuilder
    private func cell(for program: LiveTvProgram) -> some View {
        if let start = program.startDate, let end = program.endDate, end > start {
            let visibleStart = max(start, windowStart)
            let duration = end.timeIntervalSince(visibleStart)
            let cellWidth = GuideLayout.width(forDuration: duration)
            FocusableProgramCell(
                program: program,
                width: cellWidth,
                onSelect: { onSelectProgram(program) }
            )
        } else {
            FocusableProgramCell(
                program: program,
                width: GuideLayout.minimumProgramCellWidth,
                onSelect: { onSelectProgram(program) }
            )
        }
    }

    private var emptyLane: some View {
        Text("No information")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .frame(width: laneWidth, height: GuideLayout.rowHeight, alignment: .leading)
            .background(.white.opacity(0.04))
    }

    private var laneWidth: CGFloat {
        let minutes = windowEnd.timeIntervalSince(windowStart) / 60.0
        return CGFloat(minutes) * GuideLayout.pixelsPerMinute
    }
}

// MARK: - Program cell (focusable)

private struct FocusableProgramCell: View {
    let program: LiveTvProgram
    let width: CGFloat
    let onSelect: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onSelect) {
            content
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
        .focusedValue(\.focusedGuideProgram, isFocused ? program : nil)
    }

    // Static content lives OUTSIDE any TimelineView so @FocusState changes
    // are reflected immediately. Only the time-dependent overlay (airing-now
    // tint, progress bar, LIVE badge) uses its own periodic TimelineView.
    private var content: some View {
        ZStack(alignment: .topLeading) {
            // Focus-driven background tint — responds to @FocusState instantly.
            focusBackground

            // Static text content: title and time range never change per minute.
            VStack(alignment: .leading, spacing: 4) {
                // Badge row placeholder — LIVE badge is rendered in the overlay
                // below so it stays in sync with the time-keyed airing state.
                // Premiere/Repeat tags are static metadata and live here.
                HStack(spacing: 6) {
                    if program.isPremiere == true {
                        tag("PREMIERE", color: .pink)
                    } else if program.isRepeat == true {
                        tag("REPEAT", color: .gray)
                    }
                }

                Text(program.name)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary.opacity(isFocused ? 1.0 : 0.9))
                if let timeRange = LiveTvFormat.timeRange(start: program.startDate, end: program.endDate) {
                    Text(timeRange)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)

            // Time-dependent overlay: airing-now background tint, LIVE badge,
            // and progress bar — each rebuild once per minute at most.
            ProgramLiveOverlay(program: program)
        }
        .frame(width: width, height: GuideLayout.rowHeight, alignment: .topLeading)
        .padding(.horizontal, 2)
    }

    // Focus-tint layer — reads isFocused directly, never inside a closure.
    @ViewBuilder
    private var focusBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(isFocused ? 0.18 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? .white.opacity(0.6) : .white.opacity(0.10), lineWidth: 1)
            )
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color, in: Capsule())
    }
}

// MARK: - Live overlay (time-dependent parts only)

/// Renders the airing-now background tint, LIVE badge, and progress bar.
/// Contains its own small TimelineView so only these time-driven elements
/// rebuild on the periodic tick — the surrounding static cell content is
/// unaffected.
private struct ProgramLiveOverlay: View {
    let program: LiveTvProgram

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let isAiringNow: Bool = {
                guard let start = program.startDate, let end = program.endDate else { return false }
                return now >= start && now < end
            }()
            let progress = LiveTvFormat.progressFraction(
                start: program.startDate,
                end: program.endDate,
                now: now
            )

            ZStack(alignment: .topLeading) {
                // Airing-now background tint layer (below the badge/progress).
                if isAiringNow {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.30))
                }

                // LIVE badge in the top-left badge row position.
                if isAiringNow {
                    HStack(spacing: 6) {
                        LiveBadge(label: "LIVE")
                    }
                    .padding(12)
                }

                // Progress bar pinned to the bottom.
                if isAiringNow, let progress {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(LiveTVTheme.live.opacity(0.8))
                            .frame(width: geo.size.width * progress, height: 3)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Focused-program footer

private struct FocusedProgramFooter: View {
    let program: LiveTvProgram?
    let channel: LiveTvChannel?
    let serverURL: URL

    var body: some View {
        Group {
            if let program {
                HStack(alignment: .top, spacing: 16) {
                    if let channel {
                        ChannelLogoView(channel: channel, serverURL: serverURL, maxWidth: 240)
                            .frame(width: 80, height: 56)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(program.name)
                                .font(.title3.weight(.semibold))
                                .lineLimit(1)
                            if let year = program.productionYear {
                                Text(String(year))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let rating = program.officialRating {
                                Text(rating)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        if let episodeTitle = program.episodeTitle {
                            Text(episodeTitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let overview = program.overview {
                            Text(overview)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: program?.id)
    }
}

// MARK: - Filter pill bar

struct CategoryFilterBar: View {
    let selected: GuideCategory
    let onSelect: (GuideCategory) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(GuideCategory.allCases) { category in
                FilterPill(
                    title: category.title,
                    icon: category.icon,
                    isSelected: category == selected
                ) {
                    onSelect(category)
                }
            }
        }
        .focusSection()
    }
}

private struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(background, in: Capsule())
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
    }

    private var background: Color {
        if isSelected { return LiveTVTheme.accent.opacity(0.7) }
        if isFocused { return Color.white.opacity(0.18) }
        return LiveTVTheme.surface
    }
}

// MARK: - Focus values

struct FocusedGuideProgramKey: FocusedValueKey {
    typealias Value = LiveTvProgram
}

struct FocusedGuideChannelKey: FocusedValueKey {
    typealias Value = LiveTvChannel
}

extension FocusedValues {
    var focusedGuideProgram: LiveTvProgram? {
        get { self[FocusedGuideProgramKey.self] }
        set { self[FocusedGuideProgramKey.self] = newValue }
    }
    var focusedGuideChannel: LiveTvChannel? {
        get { self[FocusedGuideChannelKey.self] }
        set { self[FocusedGuideChannelKey.self] = newValue }
    }
}
