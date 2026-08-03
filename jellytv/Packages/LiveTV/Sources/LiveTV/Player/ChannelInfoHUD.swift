import SwiftUI
import JellyfinAPI
import DesignSystem

/// Top-strip overlay shown over live video for ~3s on every tune and on
/// remote-tap. Auto-hides after 3s of inactivity. Channel logo + number/name +
/// current program title + thin progress bar.
struct ChannelInfoHUD: View {
    let channel: LiveTvChannel
    let serverURL: URL
    let program: LiveTvProgram?
    let isVisible: Bool

    var body: some View {
        VStack {
            if isVisible {
                content
                    .padding(.horizontal, 36)
                    .padding(.vertical, 18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LiveTVTheme.divider, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
                    .padding(.horizontal, 60)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        .allowsHitTesting(false)
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 18) {
            ChannelLogoView(channel: channel, serverURL: serverURL, maxWidth: 200)
                .frame(width: 80, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let number = channel.number, !number.isEmpty {
                        Text(number)
                            .font(LiveTVTypography.channelNumber)
                            .foregroundStyle(LiveTVTheme.accent)
                    }
                    Text(channel.name)
                        .font(LiveTVTypography.channelName)
                        .foregroundStyle(LiveTVTheme.text)
                }
                if let program {
                    Text(program.name)
                        .font(LiveTVTypography.programTitle)
                        .foregroundStyle(LiveTVTheme.text)
                        .lineLimit(1)
                    if let progress = LiveTvFormat.progressFraction(
                        start: program.startDate,
                        end: program.endDate,
                        now: Date()
                    ) {
                        progressBar(progress: progress)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LiveTVTheme.divider)
                Capsule()
                    .fill(LiveTVTheme.live)
                    .frame(width: max(0, geo.size.width * progress))
            }
        }
        .frame(height: 3)
        .frame(maxWidth: 320)
    }
}
