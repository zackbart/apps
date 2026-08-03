import SwiftUI
import NukeUI
import JellyfinAPI
import DesignSystem

/// Full-screen program detail. Backdrop, title, time, overview, then a
/// horizontal action row: Watch (if airing now) and Record (toggle).
public struct ProgramDetailView: View {
    @Bindable var model: ProgramDetailModel
    let serverURL: URL
    let onWatchChannel: (String) -> Void
    let onDismiss: () -> Void

    public init(
        model: ProgramDetailModel,
        serverURL: URL,
        onWatchChannel: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.model = model
        self.serverURL = serverURL
        self.onWatchChannel = onWatchChannel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop
            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 18) {
                headerBadges
                Text(model.program.name)
                    .font(.system(size: 56, weight: .heavy))
                    .lineLimit(2)
                metaRow
                if let overview = model.program.overview {
                    Text(overview)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .frame(maxWidth: 1100, alignment: .leading)
                }
                actionRow
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 80)
            .padding(.top, 100)
        }
        .ignoresSafeArea()
        .task {
            await model.refreshRecordState()
        }
    }

    private func channelHeaderText(channelName: String) -> String {
        if let number = model.program.channelNumber, !number.isEmpty {
            return "\(channelName) · CH \(number)"
        }
        return channelName
    }

    private var headerBadges: some View {
        HStack(spacing: 10) {
            if isAiringNow {
                LiveBadge(label: "LIVE")
            }
            if model.program.isPremiere == true {
                tag("PREMIERE", color: .pink)
            } else if model.program.isRepeat == true {
                tag("REPEAT", color: .gray)
            }
            if let channelName = model.program.channelName {
                HStack(spacing: 6) {
                    Image(systemName: "tv")
                    Text(channelHeaderText(channelName: channelName))
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: 12) {
            if let timeRange = LiveTvFormat.timeRange(start: model.program.startDate, end: model.program.endDate) {
                Label(timeRange, systemImage: "clock")
                    .labelStyle(.titleAndIcon)
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let year = model.program.productionYear {
                Text(String(year))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            if let rating = model.program.officialRating {
                Text(rating)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
            }
            if let genres = model.program.genres, !genres.isEmpty {
                Text(genres.prefix(3).joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 16) {
            if isAiringNow, let channelId = model.program.channelId {
                ActionButton(
                    title: "Watch Live",
                    systemImage: "play.fill",
                    isPrimary: true
                ) {
                    onWatchChannel(channelId)
                }
            }
            ActionButton(
                title: recordButtonTitle,
                systemImage: recordButtonIcon,
                isPrimary: !isAiringNow,
                tint: recordButtonTint
            ) {
                Task { await model.toggleRecording() }
            }
            ActionButton(
                title: "Close",
                systemImage: "xmark",
                isPrimary: false
            ) {
                onDismiss()
            }
            if model.isWorking {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(.leading, 8)
            }
            Spacer(minLength: 0)
        }
        .focusSection()
    }

    private var isAiringNow: Bool {
        guard let start = model.program.startDate,
              let end = model.program.endDate else { return false }
        let now = Date()
        return now >= start && now < end
    }

    private var recordButtonTitle: String {
        switch model.recordState {
        case .scheduled: return "Cancel Recording"
        case .recording: return "Stop Recording"
        case .notScheduled, .unknown, .error: return "Record"
        }
    }

    private var recordButtonIcon: String {
        switch model.recordState {
        case .scheduled, .recording: return "record.circle.fill"
        case .notScheduled, .unknown, .error: return "record.circle"
        }
    }

    private var recordButtonTint: Color? {
        switch model.recordState {
        case .scheduled, .recording: return .red
        default: return nil
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
    }

    @ViewBuilder
    private var backdrop: some View {
        if let url = model.program.backdropURL(serverURL: serverURL, maxWidth: 1920) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
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
            colors: [Color.accentColor.opacity(0.4), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let isPrimary: Bool
    var tint: Color? = nil
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.headline)
            .padding(.horizontal, 26)
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
        if let tint {
            return isFocused ? tint : tint.opacity(0.85)
        }
        if isPrimary {
            return isFocused ? .white : .white.opacity(0.95)
        }
        return isFocused ? .white.opacity(0.30) : .white.opacity(0.18)
    }

    private var foreground: Color {
        if tint != nil { return .white }
        return isPrimary ? .black : .white
    }
}

// MARK: - Presentation modifier

/// Sheet/full-screen presentation for `ProgramDetailView`. Shared by every
/// view that surfaces programs (Guide cells, On Now hero, Up Next shelf).
public struct ProgramDetailPresentation: ViewModifier {
    @Binding var selectedProgram: LiveTvProgram?
    let client: any JellyfinClientAPI
    let onWatchChannel: (LiveTvChannel) -> Void

    public init(
        selectedProgram: Binding<LiveTvProgram?>,
        client: any JellyfinClientAPI,
        onWatchChannel: @escaping (LiveTvChannel) -> Void
    ) {
        self._selectedProgram = selectedProgram
        self.client = client
        self.onWatchChannel = onWatchChannel
    }

    public func body(content: Content) -> some View {
        #if os(tvOS)
        content.fullScreenCover(item: $selectedProgram) { program in
            detailView(for: program)
        }
        #else
        content.sheet(item: $selectedProgram) { program in
            detailView(for: program)
        }
        #endif
    }

    @ViewBuilder
    private func detailView(for program: LiveTvProgram) -> some View {
        ProgramDetailContainer(
            program: program,
            client: client,
            onWatchChannel: onWatchChannel,
            onDismiss: { selectedProgram = nil }
        )
    }
}

private struct ProgramDetailContainer: View {
    let program: LiveTvProgram
    let client: any JellyfinClientAPI
    let onWatchChannel: (LiveTvChannel) -> Void
    let onDismiss: () -> Void

    @State private var serverURL: URL?
    @State private var model: ProgramDetailModel

    init(
        program: LiveTvProgram,
        client: any JellyfinClientAPI,
        onWatchChannel: @escaping (LiveTvChannel) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.program = program
        self.client = client
        self.onWatchChannel = onWatchChannel
        self.onDismiss = onDismiss
        _model = State(initialValue: ProgramDetailModel(program: program, client: client))
    }

    var body: some View {
        Group {
            if let serverURL {
                ProgramDetailView(
                    model: model,
                    serverURL: serverURL,
                    onWatchChannel: { channelId in
                        // Synthesize a LiveTvChannel from the program metadata,
                        // and crucially attach the program itself as
                        // `currentProgram` so the player splash + HUD render
                        // program info instead of empty state.
                        let channel = LiveTvChannel(
                            id: channelId,
                            name: program.channelName ?? "Live TV",
                            number: program.channelNumber,
                            imageTags: program.channelPrimaryImageTag.map { ["Primary": $0] },
                            currentProgram: program
                        )
                        onWatchChannel(channel)
                    },
                    onDismiss: onDismiss
                )
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .task {
            serverURL = await client.currentServerURL()
        }
    }
}
