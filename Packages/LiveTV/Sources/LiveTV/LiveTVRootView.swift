import SwiftUI
import JellyfinAPI
import DesignSystem

/// Top-level Live TV experience and the app's whole signed-in UI: two tabs —
/// Home (live-first Marquee hero + On Now shelf) and Live (the playbill).
/// The full guide grid is reachable from the Home hero's Guide button as a
/// cover. Each tab owns an `@Observable` model pulling through the shared
/// `EPGStore` so channel data is fetched once and reused.
///
/// The per-tab models are held as `@State` so they survive `body`
/// re-evaluations across tab changes — recreating them inline would discard
/// loaded content every render.
public struct LiveTVRootView: View {
    public let client: any JellyfinClientAPI

    @State private var epgStore: EPGStore
    @State private var onNowModel: OnNowModel
    @State private var playbillModel: PlaybillModel
    @State private var guideModel: GuideModel
    @State private var selectedChannel: LiveTvChannel?
    @State private var selectedProgram: LiveTvProgram?
    @State private var showGuide = false
    @State private var serverURL: URL?

    /// Last-watched channel id, persisted across launches so the Home hero
    /// can greet the user with "You were watching".
    @AppStorage("jellytv.lastWatchedChannelId") private var lastWatchedStorage: String = ""

    public init(client: any JellyfinClientAPI) {
        self.client = client
        let store = EPGStore(client: client)
        _epgStore = State(initialValue: store)
        _onNowModel = State(initialValue: OnNowModel(client: client, store: store))
        _playbillModel = State(initialValue: PlaybillModel(store: store))
        _guideModel = State(initialValue: GuideModel(client: client, store: store))
    }

    /// Bridge `@AppStorage`'s non-optional String to the Binding<String?> the
    /// guide and player presentations expect ("" means none).
    private var lastWatchedChannelId: Binding<String?> {
        Binding(
            get: { lastWatchedStorage.isEmpty ? nil : lastWatchedStorage },
            set: { lastWatchedStorage = $0 ?? "" }
        )
    }

    public var body: some View {
        TabView {
            MarqueeHomeView(
                model: onNowModel,
                lastWatchedChannelId: lastWatchedChannelId.wrappedValue,
                onWatchChannel: { selectedChannel = $0 },
                onOpenGuide: { showGuide = true }
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            PlaybillView(
                model: playbillModel,
                lastWatchedChannelId: lastWatchedChannelId.wrappedValue,
                onWatchChannel: { selectedChannel = $0 }
            )
            .tabItem {
                Label("Live", systemImage: "dot.radiowaves.left.and.right")
            }
        }
        .task {
            // Resolve server URL once for the player. Pre-warm the unfiltered
            // channel list so the zap list is ready before the first tab loads.
            serverURL = await client.currentServerURL()
            await epgStore.prewarm()
            // After both serverURL and unfilteredChannels are available,
            // kick off a background dominant-color pre-warm so channel
            // splash backgrounds render instantly on first zap.
            if let url = serverURL {
                epgStore.prewarmDominantColors(serverURL: url)
            }
        }
        .modifier(GuideCover(isPresented: $showGuide) {
            ZStack {
                LiveTVTheme.background.ignoresSafeArea()
                GuideView(
                    model: guideModel,
                    onWatchChannel: { channel in
                        showGuide = false
                        selectedChannel = channel
                    },
                    onSelectProgram: { program in
                        showGuide = false
                        selectedProgram = program
                    },
                    lastWatchedChannelId: lastWatchedChannelId
                )
            }
        })
        .modifier(LiveTVPresentations(
            selectedChannel: $selectedChannel,
            selectedProgram: $selectedProgram,
            channels: epgStore.unfilteredChannels,
            serverURL: serverURL,
            lastWatchedChannelId: lastWatchedChannelId,
            client: client
        ))
    }
}

/// Full-screen guide presentation on tvOS; falls back to a sheet on other
/// platforms (the package also builds for macOS in `swift test`).
private struct GuideCover<CoverContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let coverContent: () -> CoverContent

    init(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> CoverContent) {
        self._isPresented = isPresented
        self.coverContent = content
    }

    func body(content: Content) -> some View {
        #if os(tvOS)
        content.fullScreenCover(isPresented: $isPresented, content: coverContent)
        #else
        content.sheet(isPresented: $isPresented, content: coverContent)
        #endif
    }
}

/// Centralized full-screen / sheet presentation so each tab doesn't need to
/// own player + program-detail navigation independently.
private struct LiveTVPresentations: ViewModifier {
    @Binding var selectedChannel: LiveTvChannel?
    @Binding var selectedProgram: LiveTvProgram?
    let channels: [LiveTvChannel]
    let serverURL: URL?
    @Binding var lastWatchedChannelId: String?
    let client: any JellyfinClientAPI

    func body(content: Content) -> some View {
        content
            .modifier(ChannelPlayerPresentation(
                selectedChannel: $selectedChannel,
                channels: channels,
                serverURL: serverURL ?? URL(string: "about:blank")!,
                program: nil,
                openStream: { [client] channel, force in
                    try await client.liveTvOpenStream(channelId: channel.id, forceTranscoding: force)
                },
                closeStream: { [client] id in
                    try? await client.liveTvCloseStream(liveStreamId: id)
                },
                lastWatchedChannelId: $lastWatchedChannelId
            ))
            .modifier(ProgramDetailPresentation(
                selectedProgram: $selectedProgram,
                client: client,
                onWatchChannel: { channel in
                    selectedProgram = nil
                    selectedChannel = channel
                }
            ))
    }
}
