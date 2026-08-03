import SwiftUI
import JellyfinAPI
import DesignSystem

#if os(tvOS)
import AVKit
import UIKit
#endif

/// Hosts the live-TV player. Owns a `PlayerViewModel` that drives the state
/// machine (resolving → splash → buffering → playing → reconnecting → error).
/// Layers SwiftUI overlays per state on top of an `AVPlayerViewController`
/// (via `AVKitPlayerHost`).
public struct LiveTVPlayerView: View {
    public let initialChannel: LiveTvChannel
    public let channels: [LiveTvChannel]
    public let serverURL: URL
    public let initialProgram: LiveTvProgram?
    public let openStream: @Sendable (LiveTvChannel, _ forceTranscoding: Bool) async throws -> LiveStreamPlayback
    public let closeStream: @Sendable (String) async -> Void
    public let onDismiss: () -> Void
    public let onChannelChanged: (LiveTvChannel) -> Void

    public init(
        initialChannel: LiveTvChannel,
        channels: [LiveTvChannel],
        serverURL: URL,
        initialProgram: LiveTvProgram?,
        openStream: @escaping @Sendable (LiveTvChannel, _ forceTranscoding: Bool) async throws -> LiveStreamPlayback,
        closeStream: @escaping @Sendable (String) async -> Void,
        onDismiss: @escaping () -> Void,
        onChannelChanged: @escaping (LiveTvChannel) -> Void
    ) {
        self.initialChannel = initialChannel
        self.channels = channels
        self.serverURL = serverURL
        self.initialProgram = initialProgram
        self.openStream = openStream
        self.closeStream = closeStream
        self.onDismiss = onDismiss
        self.onChannelChanged = onChannelChanged
    }

    public var body: some View {
        #if os(tvOS)
        TVOSPlayerHost(
            initialChannel: initialChannel,
            channels: channels,
            serverURL: serverURL,
            initialProgram: initialProgram,
            openStream: openStream,
            closeStream: closeStream,
            onDismiss: onDismiss,
            onChannelChanged: onChannelChanged
        )
        .ignoresSafeArea()
        #else
        macOSStub
        #endif
    }

    #if !os(tvOS)
    private var macOSStub: some View {
        VStack(spacing: 16) {
            Text("Live TV playback is tvOS only.")
                .font(.title2)
            Button("Dismiss") { onDismiss() }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    #endif
}

#if os(tvOS)

/// tvOS-only inner view that owns the `@State` `PlayerViewModel` and the
/// `AVKitPlayerHost`. Renders AVPlayerViewController via a representable +
/// layered SwiftUI overlays per state.
@MainActor
private struct TVOSPlayerHost: View {
    let initialChannel: LiveTvChannel
    let channels: [LiveTvChannel]
    let serverURL: URL
    let initialProgram: LiveTvProgram?
    let openStream: @Sendable (LiveTvChannel, Bool) async throws -> LiveStreamPlayback
    let closeStream: @Sendable (String) async -> Void
    let onDismiss: () -> Void
    let onChannelChanged: (LiveTvChannel) -> Void

    @State private var host: AVKitPlayerHost = AVKitPlayerHost()
    @State private var viewModel: PlayerViewModel? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // AVPlayerViewController layer — visible whenever we have a
            // playback URL committed (splash overlays it during warm-up,
            // playing shows it directly, reconnecting overlays a toast).
            AVPVCRepresentable(host: host)

            if let viewModel {
                overlayLayers(for: viewModel)
            }
        }
        .task {
            await ensureViewModel()
        }
        .onDisappear {
            // Backstop: if any dismissal path bypasses onDismissRequested
            // (e.g. programmatic sheet dismissal), dismiss() is idempotent.
            viewModel?.dismiss()
        }
        .onChange(of: viewModel?.state) { _, newState in
            if let channel = newState?.channel {
                onChannelChanged(channel)
            }
            // Keep AVPVC's external metadata in sync with current channel/program.
            if let channel = newState?.channel {
                host.controller.player?.currentItem?.externalMetadata =
                    LiveTVMetadata.make(channel: channel, program: viewModel?.currentProgram)
            }
        }
    }

    @ViewBuilder
    private func overlayLayers(for viewModel: PlayerViewModel) -> some View {
        // Splash (resolving / splash / buffering)
        if viewModel.state.showsSplash, let channel = viewModel.state.channel {
            ChannelSplashView(
                channel: channel,
                serverURL: serverURL,
                program: viewModel.currentProgram
            )
            .transition(.opacity)
        }

        // Reconnecting toast over playing video
        if case .reconnecting = viewModel.state {
            ReconnectingToast(isVisible: true)
        }

        // Channel-info HUD over playing video
        if case .playing = viewModel.state, let channel = viewModel.state.channel {
            ChannelInfoHUD(
                channel: channel,
                serverURL: serverURL,
                program: viewModel.currentProgram,
                isVisible: viewModel.hudVisible
            )
        }

        // Error card replaces everything else
        if case .error(let channel, let message, let detail) = viewModel.state {
            PlayerErrorCard(
                channel: channel,
                message: message,
                detail: detail,
                onRetry: { Task { await viewModel.retry() } },
                onDismiss: {
                    viewModel.dismiss()
                    onDismiss()
                }
            )
            .transition(.opacity)
        }
    }

    private func ensureViewModel() async {
        if viewModel != nil { return }
        let net = NWPathNetworkMonitor()
        let vm = PlayerViewModel(
            initialChannel: initialChannel,
            channels: channels,
            serverURL: serverURL,
            program: initialProgram,
            openStream: { channel, force in try await openStream(channel, force) },
            closeStream: { id in await closeStream(id) },
            host: host,
            networkMonitor: net
        )
        // Wire channel up/down from the host controller to the view model.
        host.onChannelUp = { [weak vm] in vm?.channelUp() }
        host.onChannelDown = { [weak vm] in vm?.channelDown() }
        // Wire Menu-button dismiss so the stream is closed before the
        // AVPlayerViewController disappears. dismiss() is idempotent, so
        // the .onDisappear backstop is safe to also call it.
        host.controller.onDismissRequested = { [weak vm] in
            vm?.dismiss()
            onDismiss()
        }
        viewModel = vm
    }
}

private struct AVPVCRepresentable: UIViewControllerRepresentable {
    let host: AVKitPlayerHost

    func makeUIViewController(context: Context) -> PlayerHostingController {
        host.controller
    }

    func updateUIViewController(_ controller: PlayerHostingController, context: Context) {}

    static func dismantleUIViewController(
        _ controller: PlayerHostingController,
        coordinator: ()
    ) {
        // PlayerViewModel.dismiss() handles host.tearDown(); nothing to do here.
    }
}

/// Builds `AVPlayerItem.externalMetadata` so the tvOS press-up info panel
/// shows program title / channel / overview / genre — the same affordance
/// Plex Live TV provides via the OSD. AVKit lays this out for free.
enum LiveTVMetadata {
    static func make(channel: LiveTvChannel, program: LiveTvProgram?) -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []
        let title = program?.name ?? channel.name
        items.append(metadata(identifier: .commonIdentifierTitle, value: title))

        var subtitleParts: [String] = []
        if let number = channel.number, !number.isEmpty {
            subtitleParts.append("CH \(number)")
        }
        subtitleParts.append(channel.name)
        if let episodeTitle = program?.episodeTitle, !episodeTitle.isEmpty {
            subtitleParts.append(episodeTitle)
        }
        items.append(metadata(
            identifier: .iTunesMetadataTrackSubTitle,
            value: subtitleParts.joined(separator: " · ")
        ))

        if let overview = program?.overview, !overview.isEmpty {
            items.append(metadata(identifier: .commonIdentifierDescription, value: overview))
        }
        if let genres = program?.genres, !genres.isEmpty {
            items.append(metadata(identifier: .quickTimeMetadataGenre, value: genres.joined(separator: ", ")))
        }
        if let year = program?.productionYear {
            items.append(metadata(identifier: .commonIdentifierCreationDate, value: String(year)))
        }
        return items
    }

    private static func metadata(identifier: AVMetadataIdentifier, value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item.copy() as! AVMetadataItem
    }
}

#endif
