import SwiftUI
import JellyfinAPI
import DesignSystem

/// Full-screen "tuning…" splash shown while the player is resolving the
/// stream URL and waiting for AVPlayer to render the first frame. Dismissed
/// by `PlayerViewModel` when state transitions to `.playing`.
///
/// Background: vertical gradient from the channel logo's extracted dominant
/// color (top) to `LiveTVTheme.background` (bottom). If extraction fails or
/// the logo isn't loaded yet, the gradient starts at `LiveTVTheme.surface`
/// so the screen still feels intentional rather than "missing background".
struct ChannelSplashView: View {
    let channel: LiveTvChannel
    let serverURL: URL
    let program: LiveTvProgram?

    @State private var topColor: Color = LiveTVTheme.surface
    @State private var pulsing: Bool = false

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 28) {
                Spacer()

                ChannelLogoView(channel: channel, serverURL: serverURL, maxWidth: 480)
                    .frame(width: 220, height: 140)
                    .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 10)

                channelLine

                if let program {
                    programLines(program)
                }

                Spacer()

                tuningIndicator
                    .padding(.bottom, 80)
            }
            .padding(.horizontal, 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: channel.id) {
            await loadDominantColor()
        }
        .onAppear { pulsing = true }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [topColor, LiveTVTheme.background],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: topColor)
    }

    private var channelLine: some View {
        HStack(spacing: 12) {
            if let number = channel.number, !number.isEmpty {
                Text(number)
                    .font(LiveTVTypography.display)
                    .monospacedDigit()
                    .foregroundStyle(LiveTVTheme.accent)
                Text("·")
                    .font(LiveTVTypography.display)
                    .foregroundStyle(LiveTVTheme.text.opacity(0.5))
            }
            Text(channel.name)
                .font(LiveTVTypography.display)
                .foregroundStyle(LiveTVTheme.text)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    @ViewBuilder
    private func programLines(_ program: LiveTvProgram) -> some View {
        VStack(spacing: 6) {
            Text(program.name)
                .font(LiveTVTypography.programTitle)
                .foregroundStyle(LiveTVTheme.text)
                .lineLimit(1)
            if let timeRange = LiveTvFormat.timeRange(start: program.startDate, end: program.endDate) {
                Text(timeRange)
                    .font(LiveTVTypography.programTime)
                    .foregroundStyle(LiveTVTheme.secondaryText)
            }
        }
    }

    private var tuningIndicator: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(LiveTVTheme.accent)
                        .frame(width: 10, height: 10)
                        .opacity(pulsing ? 1.0 : 0.3)
                        .scaleEffect(pulsing ? 1.3 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.18),
                            value: pulsing
                        )
                }
            }
            Text("Tuning\u{2026}")
                .font(LiveTVTypography.timeLabel)
                .foregroundStyle(LiveTVTheme.text)
        }
    }

    private func loadDominantColor() async {
        let logoURL = channel.logoURL(serverURL: serverURL, maxWidth: 256)
        if let extracted = await ChannelDominantColor.shared.extract(logoURL: logoURL) {
            // Tone the extracted color down a touch so it doesn't dominate
            // the channel name's contrast — multiply alpha 0.7.
            topColor = extracted.opacity(0.7)
        }
    }
}
