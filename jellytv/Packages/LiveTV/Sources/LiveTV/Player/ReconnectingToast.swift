import SwiftUI
import DesignSystem

/// Non-blocking top-floating toast shown over live video when AVPlayer's
/// `playbackBufferEmpty` has been true for >5s (network drop / transcoder
/// stall). Disappears when buffer refills. If recovery doesn't happen
/// within ~10s, the player escalates to the full `PlayerErrorCard`.
struct ReconnectingToast: View {
    let isVisible: Bool

    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(LiveTVTheme.text)
                    Text("Reconnecting\u{2026}")
                        .font(LiveTVTypography.timeLabel)
                        .foregroundStyle(LiveTVTheme.text)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule().stroke(LiveTVTheme.divider, lineWidth: 1)
                )
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        .allowsHitTesting(false)
    }
}
