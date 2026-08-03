import SwiftUI

struct WallpaperCardView: View {
    let wallpaper: Wallpaper
    let isActive: Bool
    var isStale: Bool = false
    let onTap: () -> Void

    @State private var isHovering = false
    @State private var showPreview = false
    @State private var hoverTask: Task<Void, Never>?

    /// Only show the hover preview if we already have the video locally —
    /// we never start a remote stream on hover. Stale wallpapers never preview.
    private var previewURL: URL? {
        guard !isStale else { return nil }
        if let local = wallpaper.localFileURL {
            return local
        }
        if let cached = DownloadManager.shared.localURL(for: wallpaper.id) {
            return cached
        }
        return nil
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                thumbnailArea
                metadataArea
            }
            .background {
                RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                    .strokeBorder(
                        isHovering ? Color.primary.opacity(0.18) : Color.primary.opacity(0.06),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous))
            .compositingGroup()
            .shadow(color: .black.opacity(isHovering ? 0.14 : 0.06), radius: isHovering ? 16 : 8, x: 0, y: isHovering ? 8 : 4)
            .scaleEffect(isHovering ? 1.01 : 1)
            .animation(.easeOut(duration: 0.18), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            handleHoverChange(hovering)
        }
        .onDisappear {
            hoverTask?.cancel()
            showPreview = false
            VideoPreviewPool.shared.release(id: wallpaper.id)
        }
    }

    // MARK: - Thumbnail area

    private var thumbnailArea: some View {
        ZStack {
            ZStack {
                staticThumbnail
                    .grayscale(isStale ? 0.75 : 0)
                    .opacity(isStale ? 0.75 : 1.0)

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if showPreview, let url = previewURL {
                    VideoPreviewPlayer(
                        wallpaperID: wallpaper.id,
                        url: url,
                        isPlaying: true
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 154)
                    .clipped()
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                }
            }

            VStack {
                HStack(alignment: .top) {
                    sourceBadge
                    Spacer(minLength: 0)
                    if isActive && !isStale {
                        ActiveBadge(compact: true)
                    } else if isStale {
                        staleBadge
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Metrics.spacingS)
        }
        .frame(height: 154)
    }

    @ViewBuilder
    private var staticThumbnail: some View {
        if let thumbnailURL = wallpaper.thumbnailURL, let url = URL(string: thumbnailURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 154)
                    .clipped()
            } placeholder: {
                placeholderView
            }
        } else if let cachedThumb = ThumbnailGenerator.shared.cachedThumbnail(for: wallpaper.id),
                  let nsImage = NSImage(contentsOf: cachedThumb) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 154)
                .clipped()
        } else {
            placeholderView
        }
    }

    private var staleBadge: some View {
        Label("Missing", systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, Metrics.spacingS)
            .padding(.vertical, 4)
            .glassEffect(.regular.tint(.orange.opacity(0.45)), in: .capsule)
    }

    private var sourceBadge: some View {
        Label(wallpaper.isLocal ? "Imported" : wallpaper.resolution.rawValue, systemImage: wallpaper.isLocal ? "folder.fill" : "sparkles.rectangle.stack.fill")
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, Metrics.spacingS)
            .padding(.vertical, 4)
            .glassEffect(.regular.tint(.black.opacity(0.18)), in: .capsule)
            .foregroundStyle(.primary)
            .opacity(isStale ? 0.7 : 1)
    }

    private var placeholderView: some View {
        ZStack {
            Rectangle()
                .fill(.quaternary)
            Image(systemName: "film.stack")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 154)
    }

    // MARK: - Metadata area

    private var metadataArea: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            Text(wallpaper.title)
                .font(.callout.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            HStack(alignment: .center, spacing: Metrics.spacingM) {
                if let duration = wallpaper.duration {
                    cardMetaLabel(title: String(format: "%.0fs", duration), systemImage: "clock")
                }
                if previewURL != nil && !isActive {
                    cardMetaLabel(title: "Preview", systemImage: "play.circle")
                }

                Spacer(minLength: 0)

                if wallpaper.isLocal {
                    Image(systemName: "externaldrive.badge.checkmark")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("Imported wallpaper")
                }
            }
        }
        .padding(Metrics.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardMetaLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
    }

    // MARK: - Hover debouncing

    private func handleHoverChange(_ hovering: Bool) {
        hoverTask?.cancel()
        if hovering && previewURL != nil {
            hoverTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    showPreview = true
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showPreview = false
            }
            VideoPreviewPool.shared.release(id: wallpaper.id)
        }
    }
}
