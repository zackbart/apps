import SwiftUI
import JellyfinAPI
import DesignSystem

/// Full-screen error card shown when stream-open fails twice (auto-retry-once
/// already exhausted) or AVPlayer surfaces a fatal error after one retry.
/// Two actions: Retry (re-enters resolving state) and Dismiss (closes player).
struct PlayerErrorCard: View {
    let channel: LiveTvChannel
    let message: String
    let detail: String?
    let onRetry: () -> Void
    let onDismiss: () -> Void

    @FocusState private var focused: Action?

    enum Action: Hashable { case retry, dismiss }

    var body: some View {
        ZStack {
            LiveTVTheme.background.ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(LiveTVTheme.accent)

                VStack(spacing: 12) {
                    Text(message)
                        .font(LiveTVTypography.strongTitle)
                        .foregroundStyle(LiveTVTheme.text)
                        .multilineTextAlignment(.center)

                    Text("Couldn't tune \(channel.name).")
                        .font(.title3)
                        .foregroundStyle(LiveTVTheme.secondaryText)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(LiveTVTheme.secondaryText.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                            .frame(maxWidth: 700)
                    }
                }

                HStack(spacing: 24) {
                    Button(action: onRetry) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .frame(minWidth: 200)
                    }
                    .focused($focused, equals: .retry)
                    #if os(tvOS)
                    .buttonStyle(.card)
                    #else
                    .buttonStyle(.borderedProminent)
                    #endif

                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(.headline)
                            .frame(minWidth: 200)
                    }
                    .focused($focused, equals: .dismiss)
                    #if os(tvOS)
                    .buttonStyle(.card)
                    #else
                    .buttonStyle(.bordered)
                    #endif
                }
                .padding(.top, 20)
            }
            .padding(80)
        }
        .onAppear {
            focused = .retry
        }
    }
}
