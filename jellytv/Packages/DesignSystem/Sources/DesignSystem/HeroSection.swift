import SwiftUI
import Nuke
import NukeUI
import JellyfinAPI

private enum HeroFocusNamespace: Hashable {}

public struct HeroSection: View {
    let item: BaseItemDto
    let serverURL: URL
    let onPlay: () -> Void
    let onDetail: () -> Void

    public init(
        item: BaseItemDto,
        serverURL: URL,
        onPlay: @escaping () -> Void,
        onDetail: @escaping () -> Void
    ) {
        self.item = item
        self.serverURL = serverURL
        self.onPlay = onPlay
        self.onDetail = onDetail
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let backdropURL = item.imageURL(serverURL: serverURL, type: .backdrop, maxWidth: 1920) {
                LazyImage(url: backdropURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .aspectRatio(16/9, contentMode: .fill)
                .animation(.easeInOut(duration: 0.35), value: backdropURL)
            } else {
                Color.gray.opacity(0.3)
                    .aspectRatio(16/9, contentMode: .fill)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 16) {
                Text(item.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(2)

                if let overview = item.overview {
                    Text(overview)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                HStack(spacing: 20) {
                    Button(action: onPlay) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Play")
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.borderless)

                    Button(action: onDetail) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                            Text("More Info")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(40)
        }
        .containerRelativeFrame(.horizontal)
    }
}